// EP group → colour mapping (consistent with EP palette)
export const EP_GROUP_COLORS: Record<string, string> = {
    EPP: '#3399FF',
    'S&D': '#FF0000',
    'Renew Europe': '#FF8C00',
    ALDE: '#FF8C00',
    RE: '#FF8C00',
    Greens: '#009900',
    'Greens/EFA': '#009900',
    ECR: '#0099CC',
    ID: '#804040',
    'GUE/NGL': '#990000',
    'Non-Inscrits': '#8B4513',
    NI: '#8B4513',
    Other: '#CCCCCC',
};

export function epColor(acronym: string | null): string {
    if (!acronym) return EP_GROUP_COLORS.Other;
    return EP_GROUP_COLORS[acronym] ?? EP_GROUP_COLORS.Other;
}

export const METRICS = [
    { key: 'gdp_per_capita_eur', label: 'GDP per capita (€)' },
    { key: 'population', label: 'Population' },
    { key: 'winner_share_pct', label: 'Winner vote share (%)' },
    { key: 'turnout_pct', label: 'Turnout (%)' },
    { key: 'expenditure_per_capita', label: 'Kohesio expenditure per capita (€)' },
    { key: 'total_expenditure_eur', label: 'Kohesio total expenditure (€)' },
    { key: 'project_count', label: 'Kohesio project count' },
] as const;

export type MetricKey = (typeof METRICS)[number]['key'];

export function formatNum(v: number | null, key: MetricKey): string {
    if (v == null) return 'N/A';
    if (key === 'gdp_per_capita_eur' || key === 'expenditure_per_capita')
        return `€${v.toLocaleString('en', { maximumFractionDigits: 0 })}`;
    if (key === 'total_expenditure_eur') return `€${(v / 1e6).toFixed(1)}M`;
    if (key === 'winner_share_pct' || key === 'turnout_pct') return `${v.toFixed(1)}%`;
    if (key === 'population') return v.toLocaleString('en', { maximumFractionDigits: 0 });
    return String(v);
}
