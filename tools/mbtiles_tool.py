#!/usr/bin/env python3
"""
MBTiles & High-Resolution Satellite Map Tool for AeroTHON-GCS / QGroundControl

Capabilities:
1. Generate standard .mbtiles packages from high-res satellite imagery.
2. Directly import/sync .mbtiles packages into QGC's native tile cache database (qgcMapCache.db).
3. Pre-fetch and bake crystal-clear satellite imagery for any field / coordinate bounding box up to Zoom 21+.
"""

import os
import sys
import math
import time
import sqlite3
import argparse
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

# Map Provider IDs for QGC
PROVIDER_IDS = {
    "Google Satellite": 2,
    "Google Hybrid": 4,
    "Bing Hybrid": 8,
    "Bing Satellite": 7,
    "Esri Satellite": 17,
    "Mapbox Satellite": 21,
    "Mapbox Hybrid": 22,
    "Custom": 37
}

def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return (xtile, ytile)

def num2deg(xtile, ytile, zoom):
    n = 2.0 ** zoom
    lon_deg = xtile / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * ytile / n)))
    lat_deg = math.degrees(lat_rad)
    return (lat_deg, lon_deg)

def get_tile_hash(provider_type_id, x, y, z):
    """Generates the 30-char hash string expected by QGC's QGCMapUrlEngine."""
    return f"{provider_type_id:010d}{x:08d}{y:08d}{z:03d}"

def download_tile(url, headers=None, max_retries=3):
    if headers is None:
        headers = {
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as response:
                return response.read()
        except Exception:
            if attempt == max_retries - 1:
                return None
            time.sleep(0.5)
    return None

def create_mbtiles_db(mbtiles_path, name="AeroTHON High-Res Arena", bounds=None, min_zoom=0, max_zoom=20, img_format="jpg"):
    """Creates a standard specification-compliant MBTiles SQLite database."""
    conn = sqlite3.connect(mbtiles_path)
    cur = conn.cursor()
    
    cur.execute("CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT);")
    cur.execute("CREATE TABLE IF NOT EXISTS tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);")
    cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS tile_index ON tiles (zoom_level, tile_column, tile_row);")
    
    if bounds is None:
        bounds = "-180.0,-85.0,180.0,85.0"
        
    metadata = [
        ("name", name),
        ("type", "baselayer"),
        ("version", "1.0"),
        ("description", "High-Resolution Satellite Imagery for AeroTHON-GCS"),
        ("format", img_format),
        ("bounds", bounds if isinstance(bounds, str) else f"{bounds[0]},{bounds[1]},{bounds[2]},{bounds[3]}"),
        ("minzoom", str(min_zoom)),
        ("maxzoom", str(max_zoom)),
    ]
    cur.executemany("INSERT OR REPLACE INTO metadata (name, value) VALUES (?, ?);", metadata)
    conn.commit()
    return conn

def fetch_satellite_to_mbtiles(mbtiles_path, min_lat, max_lat, min_lon, max_lon, min_zoom=15, max_zoom=20, name="Flight Arena"):
    """Downloads crystal-clear satellite tiles into an .mbtiles file."""
    print(f"[MBTiles] Creating high-res satellite dataset for bounding box:")
    print(f"          Lat: [{min_lat}, {max_lat}], Lon: [{min_lon}, {max_lon}]")
    print(f"          Zoom levels: {min_zoom} to {max_zoom}")
    
    bounds_str = f"{min_lon},{min_lat},{max_lon},{max_lat}"
    conn = create_mbtiles_db(mbtiles_path, name=name, bounds=bounds_str, min_zoom=min_zoom, max_zoom=max_zoom, img_format="jpg")
    cur = conn.cursor()
    
    tile_tasks = []
    for z in range(min_zoom, max_zoom + 1):
        x_min, y_min = deg2num(max_lat, min_lon, z)
        x_max, y_max = deg2num(min_lat, max_lon, z)
        
        for x in range(min(x_min, x_max), max(x_min, x_max) + 1):
            for y in range(min(y_min, y_max), max(y_min, y_max) + 1):
                # Google Satellite / Google Maps Tile URL (High-res sub-meter global coverage)
                url = f"https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
                # MBTiles uses TMS coordinates (y is inverted)
                tms_y = (1 << z) - 1 - y
                tile_tasks.append((z, x, y, tms_y, url))
                
    total_tiles = len(tile_tasks)
    print(f"[MBTiles] Total tiles to fetch: {total_tiles}")
    
    downloaded = 0
    with ThreadPoolExecutor(max_workers=16) as executor:
        future_to_tile = {executor.submit(download_tile, task[4]): task for task in tile_tasks}
        for future in as_completed(future_to_tile):
            z, x, y, tms_y, url = future_to_tile[future]
            tile_data = future.result()
            if tile_data:
                cur.execute("INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?);",
                            (z, x, tms_y, tile_data))
                downloaded += 1
                if downloaded % 50 == 0 or downloaded == total_tiles:
                    print(f"  Progress: {downloaded}/{total_tiles} ({(downloaded/total_tiles)*100:.1f}%)", end="\r")
                    conn.commit()

    conn.commit()
    conn.close()
    print(f"\n[MBTiles] Saved {downloaded} tiles to {mbtiles_path}")
    return mbtiles_path

def import_mbtiles_to_qgc_cache(mbtiles_path, qgc_cache_path=None, provider_name="Bing Hybrid"):
    """Imports all tiles from an .mbtiles file directly into QGroundControl's qgcMapCache.db."""
    if qgc_cache_path is None:
        home = os.path.expanduser("~")
        candidates = [
            os.path.join(home, ".cache/QGroundControl/AeroTHON-GCS Daily/QGCMapCache/qgcMapCache.db"),
            os.path.join(home, ".cache/QGroundControl/QGroundControl Daily/QGCMapCache/qgcMapCache.db"),
            os.path.join(home, ".cache/QGroundControl/QGCMapCache/qgcMapCache.db"),
            os.path.join(home, ".qgcmapscache/qgcMapCache.db")
        ]
        for c in candidates:
            if os.path.exists(c):
                qgc_cache_path = c
                break
        if not qgc_cache_path:
            qgc_cache_path = candidates[0]
            os.makedirs(os.path.dirname(qgc_cache_path), exist_ok=True)

    print(f"[QGC Sync] Connecting to QGC Cache: {qgc_cache_path}")
    print(f"[QGC Sync] Source MBTiles: {mbtiles_path}")

    mb_conn = sqlite3.connect(mbtiles_path)
    mb_cur = mb_conn.cursor()

    # Read metadata
    meta = dict(mb_cur.execute("SELECT name, value FROM metadata").fetchall())
    set_name = meta.get("name", "High-Res Aerial Arena")
    img_format = meta.get("format", "jpg")
    
    qgc_conn = sqlite3.connect(qgc_cache_path)
    qgc_cur = qgc_conn.cursor()

    provider_id = PROVIDER_IDS.get(provider_name, 8)
    now = int(time.time())

    # Ensure tables exist
    qgc_cur.execute("""
        CREATE TABLE IF NOT EXISTS Tiles (
            tileID INTEGER PRIMARY KEY NOT NULL,
            hash TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            tile BLOB NULL,
            size INTEGER,
            type INTEGER,
            date INTEGER DEFAULT 0
        );
    """)
    qgc_cur.execute("""
        CREATE TABLE IF NOT EXISTS TileSets (
            setID INTEGER PRIMARY KEY NOT NULL,
            name TEXT NOT NULL UNIQUE,
            typeStr TEXT,
            topleftLat REAL DEFAULT 0.0,
            topleftLon REAL DEFAULT 0.0,
            bottomRightLat REAL DEFAULT 0.0,
            bottomRightLon REAL DEFAULT 0.0,
            minZoom INTEGER DEFAULT 3,
            maxZoom INTEGER DEFAULT 3,
            type INTEGER DEFAULT -1,
            numTiles INTEGER DEFAULT 0,
            defaultSet INTEGER DEFAULT 0,
            date INTEGER DEFAULT 0
        );
    """)
    qgc_cur.execute("""
        CREATE TABLE IF NOT EXISTS SetTiles (
            setID INTEGER NOT NULL REFERENCES TileSets(setID) ON DELETE CASCADE,
            tileID INTEGER NOT NULL REFERENCES Tiles(tileID) ON DELETE CASCADE
        );
    """)

    # Check / create TileSet
    row = qgc_cur.execute("SELECT setID FROM TileSets WHERE name = ?", (set_name,)).fetchone()
    if row:
        set_id = row[0]
    else:
        qgc_cur.execute("""
            INSERT INTO TileSets (name, typeStr, minZoom, maxZoom, type, defaultSet, date)
            VALUES (?, ?, ?, ?, ?, 0, ?)
        """, (set_name, provider_name, int(meta.get("minzoom", 1)), int(meta.get("maxzoom", 21)), provider_id, now))
        set_id = qgc_cur.lastrowid

    # Read all tiles and insert into QGC cache
    tiles = mb_cur.execute("SELECT zoom_level, tile_column, tile_row, tile_data FROM tiles").fetchall()
    print(f"[QGC Sync] Importing {len(tiles)} high-resolution tiles into QGC cache...")

    imported = 0
    for z, x, tms_y, data in tiles:
        # Convert TMS y back to XYZ y
        y = (1 << z) - 1 - tms_y
        tile_hash = get_tile_hash(provider_id, x, y, z)
        size = len(data)
        
        # Insert tile
        qgc_cur.execute("""
            INSERT INTO Tiles (hash, format, tile, size, type, date)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(hash) DO UPDATE SET tile=excluded.tile, size=excluded.size, date=excluded.date
        """, (tile_hash, img_format, data, size, provider_id, now))
        
        tile_id = qgc_cur.execute("SELECT tileID FROM Tiles WHERE hash = ?", (tile_hash,)).fetchone()[0]
        qgc_cur.execute("INSERT OR IGNORE INTO SetTiles (setID, tileID) VALUES (?, ?)", (set_id, tile_id))
        imported += 1

    # Update tile count
    qgc_cur.execute("UPDATE TileSets SET numTiles = (SELECT count(*) FROM SetTiles WHERE setID = ?) WHERE setID = ?", (set_id, set_id))
    qgc_conn.commit()
    qgc_conn.close()
    mb_conn.close()
    print(f"[QGC Sync] SUCCESS: {imported} high-res tiles integrated into QGC cache '{set_name}'!")

def main():
    parser = argparse.ArgumentParser(description="MBTiles & High-Res Map Tool for AeroTHON-GCS")
    subparsers = parser.add_subparsers(dest="command")

    gen_parser = subparsers.add_parser("generate", help="Generate MBTiles for coordinates")
    gen_parser.add_argument("--lat", type=float, default=15.8497, help="Center latitude (default: 15.8497)")
    gen_parser.add_argument("--lon", type=float, default=74.4977, help="Center longitude (default: 74.4977)")
    gen_parser.add_argument("--radius-km", type=float, default=2.0, help="Radius in km (default: 2.0)")
    gen_parser.add_argument("--min-zoom", type=int, default=14, help="Min zoom (default: 14)")
    gen_parser.add_argument("--max-zoom", type=int, default=19, help="Max zoom (default: 19)")
    gen_parser.add_argument("--output", type=str, default="/home/deepa/AeroTHON-GCS-V2/maps/aerothon_arena.mbtiles", help="Output .mbtiles path")
    gen_parser.add_argument("--sync-qgc", action="store_true", help="Sync directly into QGC cache after generation")

    import_parser = subparsers.add_parser("import", help="Import MBTiles file into QGC cache")
    import_parser.add_argument("mbtiles_file", type=str, help="Path to .mbtiles file")
    import_parser.add_argument("--provider", type=str, default="Bing Hybrid", help="Target QGC Map Provider")

    args = parser.parse_args()

    if args.command == "generate":
        # Calculate bounding box from center + radius
        d_lat = args.radius_km / 111.0
        d_lon = args.radius_km / (111.0 * math.cos(math.radians(args.lat)))
        min_lat = args.lat - d_lat
        max_lat = args.lat + d_lat
        min_lon = args.lon - d_lon
        max_lon = args.lon + d_lon

        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        fetch_satellite_to_mbtiles(args.output, min_lat, max_lat, min_lon, max_lon, args.min_zoom, args.max_zoom)
        
        if args.sync_qgc:
            import_mbtiles_to_qgc_cache(args.output)

    elif args.command == "import":
        import_mbtiles_to_qgc_cache(args.mbtiles_file, provider_name=args.provider)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
