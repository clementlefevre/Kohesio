<script lang="ts">
  import { onMount } from "svelte";
  import { loadData, joinData } from "./lib/data";
  import ScatterChart from "./lib/ScatterChart.svelte";
  import LeafletMap from "./lib/LeafletMap.svelte";
  import { METRICS, EP_GROUP_COLORS, type MetricKey } from "./lib/colors";
  import type { ColumnTable } from "arquero";

  // ── state ──────────────────────────────────────────────────────────────────
  let elections: ColumnTable | null = $state(null);
  let kohesio: ColumnTable | null = $state(null);
  let loading = $state(true);
  let error = $state("");

  let selectedCountry = $state("ALL");
  let selectedPeriod = $state("2014-2020");
  let xKey: MetricKey = $state("gdp_per_capita_eur");
  let yKey: MetricKey = $state("expenditure_per_capita");
  let mapColorKey: MetricKey | "ep_group" = $state("ep_group");
  let selectedNuts: string | null = $state(null);

  // ── derived ────────────────────────────────────────────────────────────────
  const joined = $derived.by(() => {
    if (!elections || !kohesio) return [];
    const j = joinData(elections, kohesio, selectedPeriod);
    const filtered =
      selectedCountry === "ALL"
        ? j
        : j.filter(`d => d.country_code === '${selectedCountry}'`);
    return filtered.objects() as Record<string, unknown>[];
  });

  const countries = $derived.by(() => {
    if (!elections) return [];
    return [
      "ALL",
      ...Array.from(
        new Set(elections.array("country_code") as string[]),
      ).sort(),
    ];
  });

  const periods = $derived.by(() => {
    if (!kohesio) return ["2014-2020", "2021-2027"];
    return Array.from(
      new Set(kohesio.array("programming_period") as string[]),
    ).sort();
  });

  const selectedRow = $derived(
    selectedNuts
      ? ((joined as Record<string, unknown>[]).find(
          (r) => r.nuts_code === selectedNuts,
        ) ?? null)
      : null,
  );

  // ── load ───────────────────────────────────────────────────────────────────
  onMount(async () => {
    try {
      const d = await loadData();
      elections = d.elections;
      kohesio = d.kohesio;
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  });
</script>

<header>
  <h1>Kohesio · Election · Economy Dashboard</h1>
  <nav class="controls">
    <label>
      Country
      <select bind:value={selectedCountry}>
        {#each countries as c}
          <option value={c}>{c === "ALL" ? "All countries" : c}</option>
        {/each}
      </select>
    </label>
    <label>
      Programming period
      <select bind:value={selectedPeriod}>
        {#each periods as p}
          <option>{p}</option>
        {/each}
      </select>
    </label>
  </nav>
</header>

{#if loading}
  <p class="status">Loading data…</p>
{:else if error}
  <p class="status error">Error: {error}</p>
{:else}
  <main>
    <!-- ── Scatter panel ───────────────────────────────────────────────────── -->
    <section class="panel scatter-panel">
      <div class="panel-header">
        <h2>Scatter</h2>
        <div class="axis-controls">
          <label>
            X axis
            <select bind:value={xKey}>
              {#each METRICS as m}
                <option value={m.key}>{m.label}</option>
              {/each}
            </select>
          </label>
          <label>
            Y axis
            <select bind:value={yKey}>
              {#each METRICS as m}
                <option value={m.key}>{m.label}</option>
              {/each}
            </select>
          </label>
        </div>
      </div>
      <ScatterChart
        rows={joined as any[]}
        {xKey}
        {yKey}
        xLabel={METRICS.find((m) => m.key === xKey)?.label ?? xKey}
        yLabel={METRICS.find((m) => m.key === yKey)?.label ?? yKey}
        onSelect={(n) => (selectedNuts = n)}
      />
    </section>

    <!-- ── Map panel ──────────────────────────────────────────────────────── -->
    <section class="panel map-panel">
      <div class="panel-header">
        <h2>Map</h2>
        <label>
          Colour by
          <select bind:value={mapColorKey}>
            <option value="ep_group">EP group</option>
            {#each METRICS as m}
              <option value={m.key}>{m.label}</option>
            {/each}
          </select>
        </label>
      </div>
      <LeafletMap
        rows={joined as any[]}
        colorKey={mapColorKey}
        {selectedNuts}
        onSelect={(n) => (selectedNuts = n)}
      />
    </section>

    <!-- ── Detail panel ───────────────────────────────────────────────────── -->
    {#if selectedRow}
      {@const r = selectedRow as Record<string, unknown>}
      <aside class="detail-panel">
        <h3>{(r.region_name as string | null) ?? (r.nuts_code as string)}</h3>
        <table>
          <tbody>
            <tr><td>NUTS3</td><td>{r.nuts_code}</td></tr>
            <tr><td>Country</td><td>{r.country_code}</td></tr>
            <tr
              ><td>EP group</td>
              <td>
                <span
                  class="dot"
                  style="background:{EP_GROUP_COLORS[
                    (r.ep_group_acronym as string) ?? ''
                  ] ?? '#ccc'}"
                ></span>
                {r.ep_group_acronym ?? "N/A"}
              </td>
            </tr>
            <tr
              ><td>Winner</td><td
                >{r.latest_winner ?? "N/A"} ({r.latest_election_year ?? ""})</td
              ></tr
            >
            <tr
              ><td>Vote share</td><td
                >{r.winner_share_pct != null
                  ? (r.winner_share_pct as number).toFixed(1) + "%"
                  : "N/A"}</td
              ></tr
            >
            <tr
              ><td>Turnout</td><td
                >{r.turnout_pct != null
                  ? (r.turnout_pct as number).toFixed(1) + "%"
                  : "N/A"}</td
              ></tr
            >
            <tr
              ><td>Population</td><td
                >{r.population != null
                  ? (r.population as number).toLocaleString()
                  : "N/A"}</td
              ></tr
            >
            <tr
              ><td>GDP/capita</td><td
                >{r.gdp_per_capita_eur != null
                  ? "€" + (r.gdp_per_capita_eur as number).toLocaleString()
                  : "N/A"}</td
              ></tr
            >
            {#if r.project_count != null}
              <tr
                ><td>Projects ({selectedPeriod})</td><td>{r.project_count}</td
                ></tr
              >
              <tr
                ><td>Total expenditure</td><td
                  >€{((r.total_expenditure_eur as number) / 1e6).toFixed(
                    1,
                  )}M</td
                ></tr
              >
              <tr
                ><td>Exp. per capita</td><td
                  >{r.expenditure_per_capita != null
                    ? "€" + (r.expenditure_per_capita as number).toFixed(0)
                    : "N/A"}</td
                ></tr
              >
            {:else}
              <tr
                ><td colspan="2" class="muted"
                  >No Kohesio data for {selectedPeriod}</td
                ></tr
              >
            {/if}
          </tbody>
        </table>
        <button onclick={() => (selectedNuts = null)}>✕ Close</button>
      </aside>
    {/if}
  </main>

  <!-- EP group legend -->
  <footer class="legend">
    {#each Object.entries(EP_GROUP_COLORS).filter(([k]) => k !== "Other") as [acronym, color]}
      <span class="legend-item">
        <span class="dot" style="background:{color}"></span>
        {acronym}
      </span>
    {/each}
    <span class="muted"
      >· Bubble size ∝ population · Click a point or region to inspect</span
    >
  </footer>
{/if}

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, sans-serif;
    background: #0f1117;
    color: #e8eaf0;
  }

  header {
    display: flex;
    align-items: center;
    gap: 1.5rem;
    padding: 0.6rem 1.2rem;
    background: #1a1d27;
    border-bottom: 1px solid #2d3145;
    flex-wrap: wrap;
  }

  h1 {
    margin: 0;
    font-size: 1.1rem;
    font-weight: 600;
    white-space: nowrap;
  }

  .controls {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    align-items: center;
  }

  label {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.82rem;
    color: #aab;
  }

  select {
    background: #22263a;
    border: 1px solid #3a3f5c;
    color: #e8eaf0;
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 0.82rem;
  }

  main {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto auto;
    gap: 0.8rem;
    padding: 0.8rem;
    min-height: calc(100vh - 110px);
  }

  .panel {
    background: #1a1d27;
    border: 1px solid #2d3145;
    border-radius: 8px;
    padding: 0.8rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .panel-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .panel-header h2 {
    margin: 0;
    font-size: 0.9rem;
    font-weight: 600;
    color: #aab;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .axis-controls {
    display: flex;
    gap: 0.8rem;
    flex-wrap: wrap;
  }

  .detail-panel {
    grid-column: 1 / -1;
    background: #1a1d27;
    border: 1px solid #3a5c9c;
    border-radius: 8px;
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .detail-panel h3 {
    margin: 0;
    font-size: 1rem;
  }

  .detail-panel table {
    border-collapse: collapse;
    font-size: 0.85rem;
    max-width: 540px;
  }

  .detail-panel td {
    padding: 2px 10px 2px 0;
    color: #ccd;
  }

  .detail-panel td:first-child {
    color: #778;
    white-space: nowrap;
  }

  .detail-panel button {
    align-self: flex-start;
    background: #2a2f45;
    border: 1px solid #44496a;
    color: #ccd;
    border-radius: 4px;
    padding: 3px 10px;
    cursor: pointer;
    font-size: 0.8rem;
  }

  .dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 3px;
    vertical-align: middle;
  }

  .legend {
    display: flex;
    gap: 1rem;
    padding: 0.5rem 1.2rem;
    background: #1a1d27;
    border-top: 1px solid #2d3145;
    font-size: 0.78rem;
    flex-wrap: wrap;
    align-items: center;
    color: #aab;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 3px;
  }

  .muted {
    color: #556;
    font-style: italic;
  }

  .status {
    padding: 2rem;
    text-align: center;
    color: #aab;
  }

  .status.error {
    color: #f66;
  }
</style>
