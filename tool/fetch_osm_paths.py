"""
Fetch pedestrian / bike / road ways from OpenStreetMap via the Overpass API
and write a compact GeoJSON graph asset for the app to consume at runtime.

Usage:
    python tool/fetch_osm_paths.py           # use cached assets/data/osm_raw.json
    python tool/fetch_osm_paths.py --fetch   # re-fetch from Overpass

Output:
    assets/paths.geojson  (FeatureCollection of LineStrings with
                           properties {type: walk|bike|road, oneWay: bool})

Campus bbox matches the _bounds* constants in lib/screens/map_screen.dart.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

BBOX = (14.055335, 100.57105, 14.089425, 100.64185)  # (S, W, N, E)
CACHE = "tool/.osm_cache.json"
OUT = "assets/paths.geojson"

QUERY = (
    f"[out:json][timeout:60];"
    f"(way[\"highway\"]({BBOX[0]},{BBOX[1]},{BBOX[2]},{BBOX[3]}););"
    f"out geom;"
)

# Pedestrian-only infrastructure -> walk
WALK_HIGHWAYS = {"footway", "path", "pedestrian", "steps", "corridor", "platform"}
# Cycle-only infrastructure -> bike
BIKE_HIGHWAYS = {"cycleway"}
# Motor vehicle ways -> road  (pedestrians can still use these via profile
# weights; we classify by primary purpose, not by permissive access)
ROAD_HIGHWAYS = {
    "service", "residential", "unclassified", "living_street", "track",
    "tertiary", "tertiary_link",
    "secondary", "secondary_link",
    "primary", "primary_link",
    "trunk", "trunk_link",
    "motorway", "motorway_link",
}


def fetch() -> dict:
    print("Fetching from Overpass...", file=sys.stderr)
    data = urllib.parse.urlencode({"data": QUERY}).encode()
    with urllib.request.urlopen(
        "https://overpass-api.de/api/interpreter", data=data, timeout=180
    ) as r:
        return json.load(r)


def classify(tags: dict) -> str | None:
    hw = tags.get("highway", "")
    if hw in WALK_HIGHWAYS:
        return "walk"
    if hw in BIKE_HIGHWAYS:
        return "bike"
    if hw in ROAD_HIGHWAYS:
        return "road"
    return None


def in_bbox(lat: float, lon: float) -> bool:
    return BBOX[0] <= lat <= BBOX[2] and BBOX[1] <= lon <= BBOX[3]


def main() -> None:
    if "--fetch" in sys.argv or not os.path.exists(CACHE):
        raw = fetch()
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump(raw, f)
    else:
        print(f"Using cached {CACHE} (pass --fetch to refresh)", file=sys.stderr)
        with open(CACHE, encoding="utf-8") as f:
            raw = json.load(f)

    features = []
    counts = {"walk": 0, "bike": 0, "road": 0}

    for el in raw["elements"]:
        if el.get("type") != "way":
            continue
        tags = el.get("tags", {})
        geom = el.get("geometry", [])
        if len(geom) < 2:
            continue

        edge_type = classify(tags)
        if edge_type is None:
            continue

        # Access restrictions
        if edge_type == "walk" and tags.get("foot") == "no":
            continue
        if edge_type == "bike" and tags.get("bicycle") == "no":
            continue
        if edge_type == "road" and tags.get("motor_vehicle") == "no":
            continue

        # Clip: keep the way only if it has at least one vertex on campus.
        # We keep the full geometry rather than splitting — the graph loader
        # won't care about out-of-bbox vertices since nothing else connects
        # to them.
        if not any(in_bbox(p["lat"], p["lon"]) for p in geom):
            continue

        one_way = tags.get("oneway") == "yes"
        # Round to 7 decimals (~1.1cm) so identical junction points dedupe
        # reliably in the runtime loader.
        coords = [[round(p["lon"], 7), round(p["lat"], 7)] for p in geom]

        features.append({
            "type": "Feature",
            "geometry": {"type": "LineString", "coordinates": coords},
            "properties": {"type": edge_type, "oneWay": one_way},
        })
        counts[edge_type] += 1

    out = {"type": "FeatureCollection", "features": features}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))

    size_kb = os.path.getsize(OUT) / 1024
    print(f"Wrote {len(features)} features to {OUT} ({size_kb:.0f} KB)")
    print(f"  walk={counts['walk']}  bike={counts['bike']}  road={counts['road']}")


if __name__ == "__main__":
    main()
