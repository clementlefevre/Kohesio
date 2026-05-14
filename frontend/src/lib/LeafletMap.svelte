<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import L from "leaflet";
    import { epColor } from "./colors";
    import type { MetricKey } from "./colors";

    interface Row {
        nuts_code: string;
        region_name: string | null;
        country_code: string;
        ep_group_acronym: string | null;
        latest_winner: string | null;
        latest_election_year: number | null;
        [key: string]: unknown;
    }

    interface Props {
        rows: Row[];
        colorKey: MetricKey | "ep_group";
        selectedNuts: string | null;
        onSelect?: (nutsCode: string | null) => void;
    }

    let { rows, colorKey, selectedNuts, onSelect }: Props = $props();

    let mapEl: HTMLDivElement;
    let map: L.Map | null = null;
    let geojsonLayer: L.GeoJSON | null = null;
    let layerByNuts: Record<string, L.Layer> = {};

    // Eurostat GISCO NUTS3 2021 GeoJSON (20M scale, WGS84)
    const GEOJSON_URL =
        "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/NUTS_RG_20M_2021_4326_LEVL_3.geojson";

    let geoData: GeoJSON.FeatureCollection | null = null;

    const rowByNuts = $derived(
        Object.fromEntries(rows.map((r) => [r.nuts_code, r])),
    );

    function numericRange() {
        if (colorKey === "ep_group") return { min: 0, max: 1 };
        const vals = rows
            .map((r) => r[colorKey] as number)
            .filter((v) => v != null && isFinite(v));
        return { min: Math.min(...vals), max: Math.max(...vals) };
    }

    function featureColor(nutsCode: string): string {
        const row = rowByNuts[nutsCode];
        if (!row) return "#e0e0e0";
        if (colorKey === "ep_group") return epColor(row.ep_group_acronym);
        const v = row[colorKey] as number | null;
        if (v == null) return "#e0e0e0";
        const { min, max } = numericRange();
        const t = max > min ? (v - min) / (max - min) : 0.5;
        // Blue-to-red gradient
        const r = Math.round(255 * t);
        const b = Math.round(255 * (1 - t));
        return `rgb(${r},80,${b})`;
    }

    function styleFeature(feature?: GeoJSON.Feature): L.PathOptions {
        if (!feature) return {};
        const code = feature.properties?.NUTS_ID as string;
        const isSelected = code === selectedNuts;
        return {
            fillColor: featureColor(code),
            weight: isSelected ? 3 : 0.5,
            color: isSelected ? "#ffff00" : "#666",
            opacity: 1,
            fillOpacity: rowByNuts[code] ? 0.75 : 0.15,
        };
    }

    function buildLayer() {
        if (!map || !geoData) return;
        geojsonLayer?.remove();
        layerByNuts = {};

        geojsonLayer = L.geoJSON(geoData, {
            style: styleFeature,
            onEachFeature(feature, layer) {
                const code = feature.properties?.NUTS_ID as string;
                layerByNuts[code] = layer;
                const row = rowByNuts[code];
                const label =
                    row?.region_name ?? feature.properties?.NUTS_NAME ?? code;
                layer.bindTooltip(`<b>${label}</b> (${code})`, {
                    sticky: true,
                });
                layer.on("click", () =>
                    onSelect?.(code === selectedNuts ? null : code),
                );
            },
        }).addTo(map);
    }

    $effect(() => {
        if (!geojsonLayer || !geoData) return;
        geojsonLayer.setStyle(styleFeature);
        // Re-highlight selected
        if (selectedNuts) {
            const layer = layerByNuts[selectedNuts] as L.Path | undefined;
            layer?.setStyle({ weight: 3, color: "#ffff00" });
        }
    });

    onMount(() => {
        map = L.map(mapEl, { preferCanvas: true }).setView([51, 10], 4);
        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "© OpenStreetMap contributors",
            maxZoom: 12,
        }).addTo(map);

        fetch(GEOJSON_URL)
            .then((r) => r.json())
            .then((data: GeoJSON.FeatureCollection) => {
                geoData = data;
                buildLayer();
            });
    });

    $effect(() => {
        // Rebuild layer when data or colorKey changes
        // eslint-disable-next-line @typescript-eslint/no-unused-expressions
        rows;
        colorKey;
        buildLayer();
    });

    onDestroy(() => map?.remove());
</script>

<div bind:this={mapEl} class="map-container"></div>

<style>
    .map-container {
        width: 100%;
        height: 100%;
        min-height: 420px;
    }
</style>
