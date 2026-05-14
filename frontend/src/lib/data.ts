import * as aq from 'arquero';
import type { ColumnTable } from 'arquero';

export interface ElectionRow {
    country_code: string;
    nuts_code: string;
    region_name: string | null;
    // NED (older elections — relevant for 2014-2020 programming period)
    ned_winner: string | null;
    ned_winner_en: string | null;
    ned_election_year: number | null;
    ned_ep_group: string | null;
    ned_winner_share_pct: number | null;
    ned_turnout_pct: number | null;
    // LGC / HU (more recent elections — relevant for 2021-2027 programming period)
    lgc_winner: string | null;
    lgc_election_year: number | null;
    lgc_ep_group: string | null;
    lgc_winner_share_pct: number | null;
    lgc_turnout_pct: number | null;
    // Derived by joinData() based on selected period
    latest_winner?: string | null;
    latest_election_year?: number | null;
    ep_group_acronym?: string | null;
    winner_share_pct?: number | null;
    turnout_pct?: number | null;
    population: number | null;
    gdp_per_capita_eur: number | null;
}

export interface KohesioRow {
    nuts_code: string;
    country_code: string;
    programming_period: string;
    nuts3_label: string | null;
    project_count: number;
    total_expenditure_eur: number;
    total_eu_budget_eur: number;
    avg_cofinancing_pct: number | null;
}

export interface JoinedRow extends ElectionRow {
    programming_period?: string;
    project_count?: number;
    total_expenditure_eur?: number;
    total_eu_budget_eur?: number;
    avg_cofinancing_pct?: number | null;
    expenditure_per_capita?: number | null;
}

async function fetchArrow(url: string) {
    const buf = await fetch(url).then((r) => r.arrayBuffer());
    return aq.fromArrow(buf);
}

export async function loadData() {
    const [elections, kohesio] = await Promise.all([
        fetchArrow('/data/election_nuts3.arrow'),
        fetchArrow('/data/kohesio_nuts3.arrow'),
    ]);
    return { elections, kohesio };
}

/** Join elections + kohesio on nuts_code, compute period-appropriate party columns */
export function joinData(elections: aq.ColumnTable, kohesio: aq.ColumnTable, period: string) {
    const k = kohesio
        .filter(aq.escape((d: KohesioRow) => d.programming_period === period))
        .select(['nuts_code', 'project_count', 'total_expenditure_eur', 'total_eu_budget_eur', 'avg_cofinancing_pct']);

    // For 2014-2020: prefer NED elections (temporally appropriate), fallback to LGC
    // For 2021-2027: prefer LGC elections (more recent), fallback to NED
    const preferLgc = period === '2021-2027';

    return elections
        .join_left(k, 'nuts_code')
        .derive({
            ep_group_acronym: aq.escape((d: ElectionRow) =>
                preferLgc
                    ? (d.lgc_ep_group ?? d.ned_ep_group ?? null)
                    : (d.ned_ep_group ?? d.lgc_ep_group ?? null)
            ),
            latest_winner: aq.escape((d: ElectionRow) =>
                preferLgc
                    ? (d.lgc_winner ?? d.ned_winner ?? null)
                    : (d.ned_winner ?? d.lgc_winner ?? null)
            ),
            latest_election_year: aq.escape((d: ElectionRow) =>
                preferLgc
                    ? (d.lgc_election_year ?? d.ned_election_year ?? null)
                    : (d.ned_election_year ?? d.lgc_election_year ?? null)
            ),
            winner_share_pct: aq.escape((d: ElectionRow) =>
                preferLgc
                    ? (d.lgc_winner_share_pct ?? d.ned_winner_share_pct ?? null)
                    : (d.ned_winner_share_pct ?? d.lgc_winner_share_pct ?? null)
            ),
            turnout_pct: aq.escape((d: ElectionRow) =>
                preferLgc
                    ? (d.lgc_turnout_pct ?? d.ned_turnout_pct ?? null)
                    : (d.ned_turnout_pct ?? d.lgc_turnout_pct ?? null)
            ),
            expenditure_per_capita: aq.escape((d: JoinedRow) =>
                d.total_expenditure_eur != null && d.population != null && d.population > 0
                    ? d.total_expenditure_eur / d.population
                    : null
            ),
        });
}
