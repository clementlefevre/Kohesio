<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import * as echarts from "echarts";
    import { epColor, formatNum, type MetricKey } from "./colors";

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
        xKey: MetricKey;
        yKey: MetricKey;
        xLabel: string;
        yLabel: string;
        onSelect?: (nutsCode: string | null) => void;
    }

    let { rows, xKey, yKey, xLabel, yLabel, onSelect }: Props = $props();

    let container: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    function buildSeries(data: Row[]) {
        return [
            {
                type: "scatter",
                symbolSize: (d: number[]) => {
                    const pop = d[2];
                    if (!pop) return 6;
                    return Math.max(4, Math.min(30, Math.sqrt(pop / 5000)));
                },
                data: data
                    .filter((r) => r[xKey] != null && r[yKey] != null)
                    .map((r) => ({
                        value: [
                            r[xKey] as number,
                            r[yKey] as number,
                            (r["population"] as number) ?? 0,
                        ],
                        itemStyle: {
                            color: epColor(r.ep_group_acronym),
                            opacity: 0.8,
                        },
                        nuts_code: r.nuts_code,
                        region_name: r.region_name ?? r.nuts_code,
                        country: r.country_code,
                        ep_group: r.ep_group_acronym ?? "N/A",
                        winner: r.latest_winner ?? "N/A",
                        year: r.latest_election_year ?? "N/A",
                    })),
                emphasis: { scale: 1.5 },
            },
        ];
    }

    function initChart() {
        chart = echarts.init(container, null, { renderer: "canvas" });
        chart.on("click", (params) => {
            const raw = params.data as { nuts_code?: string };
            onSelect?.(raw?.nuts_code ?? null);
        });
        renderChart();
    }

    function renderChart() {
        if (!chart) return;
        chart.setOption(
            {
                tooltip: {
                    trigger: "item",
                    formatter: (
                        params: echarts.DefaultLabelFormatterCallbackParams,
                    ) => {
                        const d = params.data as {
                            region_name: string;
                            country: string;
                            ep_group: string;
                            winner: string;
                            year: string | number;
                            value: [number, number, number];
                        };
                        return [
                            `<b>${d.region_name}</b> (${d.country})`,
                            `${xLabel}: <b>${formatNum(d.value[0], xKey)}</b>`,
                            `${yLabel}: <b>${formatNum(d.value[1], yKey)}</b>`,
                            `EP group: <b>${d.ep_group}</b>`,
                            `Winner: ${d.winner} (${d.year})`,
                        ].join("<br/>");
                    },
                },
                xAxis: {
                    type: "value",
                    name: xLabel,
                    nameLocation: "middle",
                    nameGap: 30,
                    scale: true,
                },
                yAxis: {
                    type: "value",
                    name: yLabel,
                    nameLocation: "middle",
                    nameGap: 50,
                    scale: true,
                },
                series: buildSeries(rows),
                grid: { left: 70, right: 20, top: 20, bottom: 60 },
            },
            true,
        );
    }

    $effect(() => {
        // Re-render whenever rows, axis keys, or labels change
        // eslint-disable-next-line @typescript-eslint/no-unused-expressions
        rows;
        xKey;
        yKey;
        xLabel;
        yLabel;
        if (chart) {
            renderChart();
        }
    });

    onMount(() => {
        initChart();
        const ro = new ResizeObserver(() => chart?.resize());
        ro.observe(container);
        return () => ro.disconnect();
    });

    onDestroy(() => chart?.dispose());
</script>

<div bind:this={container} class="chart-container"></div>

<style>
    .chart-container {
        width: 100%;
        height: 100%;
        min-height: 380px;
    }
</style>
