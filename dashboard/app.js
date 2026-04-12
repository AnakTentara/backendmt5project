let growthChart = null;
let lastUpdateTime = null;

function formatMoney(amount) {
    if (amount === undefined || amount === null) return '$0.00';
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 }).format(amount);
}

function formatPct(val) {
    return (val !== undefined && val !== null) ? val.toFixed(1) + '%' : '0.0%';
}

function setStatus(ok) {
    const dot = document.getElementById('status-dot');
    const text = document.getElementById('sync-status');
    if (ok) {
        dot.style.background = '#34C759';
        dot.style.boxShadow = '0 0 10px #34C759';
        text.innerText = 'Live Connected';
    } else {
        dot.style.background = '#FF3B30';
        dot.style.boxShadow = '0 0 10px #FF3B30';
        text.innerText = 'Reconnecting...';
    }
}

function initChart() {
    const ctx = document.getElementById('growthChart').getContext('2d');
    let gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(0, 240, 255, 0.4)');
    gradient.addColorStop(1, 'rgba(0, 240, 255, 0.0)');

    growthChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Cumulative PnL ($)',
                data: [],
                borderColor: '#00F0FF',
                backgroundColor: gradient,
                borderWidth: 2.5,
                pointBackgroundColor: '#07090E',
                pointBorderColor: '#00F0FF',
                pointBorderWidth: 2,
                pointRadius: 4,
                pointHoverRadius: 7,
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    backgroundColor: 'rgba(10, 14, 25, 0.95)',
                    titleColor: '#8E9BAE',
                    bodyColor: '#fff',
                    borderColor: 'rgba(0, 240, 255, 0.3)',
                    borderWidth: 1,
                    padding: 14,
                    displayColors: false,
                    callbacks: {
                        label: (ctx) => '  PnL: ' + formatMoney(ctx.parsed.y)
                    }
                }
            },
            scales: {
                x: {
                    grid: { color: 'rgba(255,255,255,0.04)' },
                    ticks: { color: '#8E9BAE', maxRotation: 0 }
                },
                y: {
                    grid: { color: 'rgba(255,255,255,0.04)' },
                    ticks: { color: '#8E9BAE', callback: (v) => '$' + v.toFixed(2) }
                }
            },
            interaction: { mode: 'nearest', axis: 'x', intersect: false },
            animation: { duration: 600, easing: 'easeInOutQuart' }
        }
    });
}

function createLessonHTML(lesson, isVictory) {
    if (!lesson) return '';
    const cls = isVictory ? 'victory' : 'disaster';
    const pnlColor = isVictory ? '#34C759' : '#FF3B30';
    const pnlSign = isVictory ? '+' : '';
    const decision = lesson.decision ? lesson.decision.split('|').slice(0,4).join(' | ') : '-';
    const analysis = lesson.analysis || 'Analisis tidak tersedia.';
    return `
        <div class="lesson-item ${cls}">
            <div class="lesson-meta">
                <span class="symbol">${lesson.symbol || '?'}</span>
                <span>${lesson.date || ''}</span>
                <span style="color:${pnlColor};font-weight:600">${pnlSign}${formatMoney(lesson.pnl)}</span>
            </div>
            <div class="lesson-decision">${decision}</div>
            <div class="lesson-analysis">${analysis}</div>
        </div>
    `;
}

async function fetchStats() {
    try {
        const response = await fetch('/api/stats');
        if (!response.ok) throw new Error('HTTP ' + response.status);
        const data = await response.json();
        setStatus(true);

        // Update Equity Card
        const equityEl  = document.getElementById('kpi-equity');
        const eq        = data.equity || 0;
        equityEl.innerText  = formatMoney(eq);
        equityEl.className  = eq >= 0 ? 'text-glow' : 'text-danger';

        document.getElementById('kpi-balance').innerText = formatMoney(data.balance);

        const floatEl       = document.getElementById('kpi-floating');
        const fl            = data.floating || 0;
        floatEl.innerText   = (fl >= 0 ? '+' : '') + formatMoney(fl);
        floatEl.className   = fl < 0 ? 'text-danger' : fl > 0 ? 'text-success' : 'text-neutral';

        // Drawdown
        document.getElementById('kpi-drawdown').innerText = formatMoney(data.max_abs_drawdown || 0);

        // Track Record
        document.getElementById('kpi-wins').innerText   = data.total_wins || 0;
        document.getElementById('kpi-losses').innerText = data.total_losses || 0;
        document.getElementById('kpi-winrate').innerText = formatPct(data.win_rate);

        // Total PnL card
        const pnlEl = document.getElementById('kpi-total-pnl');
        const pnl   = data.total_pnl || 0;
        pnlEl.innerText  = (pnl >= 0 ? '+' : '') + formatMoney(pnl);
        pnlEl.className  = pnl >= 0 ? 'text-success' : 'text-danger';
        const totalTrades = (data.total_wins || 0) + (data.total_losses || 0);
        document.getElementById('trade-count').innerText = totalTrades + ' total trade terekam';

        // Chart update
        if (data.chart_data && growthChart) {
            growthChart.data.labels = data.chart_data.map(d => d.date);
            growthChart.data.datasets[0].data = data.chart_data.map(d => d.val);
            // Dynamic border color: green if positive, red if negative
            const lastVal = data.chart_data.length > 0 ? data.chart_data[data.chart_data.length - 1].val : 0;
            growthChart.data.datasets[0].borderColor = lastVal >= 0 ? '#00F0FF' : '#FF3B30';
            growthChart.update();
        }

        // Victories list
        const vicEl = document.getElementById('victories-list');
        if (data.latest_lessons && data.latest_lessons.length > 0) {
            vicEl.innerHTML = [...data.latest_lessons].reverse().slice(0, 10).map(l => createLessonHTML(l, true)).join('');
        } else {
            vicEl.innerHTML = '<p class="text-neutral" style="padding:1rem">Belum ada data victory. AI masih mengumpulkan pengalaman. 🌱</p>';
        }

        // Disasters list
        const disEl = document.getElementById('disasters-list');
        if (data.latest_disasters && data.latest_disasters.length > 0) {
            disEl.innerHTML = data.latest_disasters.map(l => createLessonHTML(l, false)).join('');
        } else {
            disEl.innerHTML = '<p class="text-neutral" style="padding:1rem">✅ Aman. Belum ada catatan disaster.</p>';
        }

        // Timestamp
        const now = new Date();
        lastUpdateTime = now;
        document.getElementById('last-update').innerText = 'Update: ' + now.toLocaleTimeString('id-ID');

    } catch (err) {
        console.error('[Dashboard] Fetch error:', err);
        setStatus(false);
    }
}

// Boot
document.addEventListener('DOMContentLoaded', () => {
    initChart();
    fetchStats();
    setInterval(fetchStats, 60000); // Sync tiap 60 detik
});
