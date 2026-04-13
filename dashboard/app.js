let growthChart = null;

function formatCurrency(val) {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
}

function renderHistoryTable(mem) {
    const body = document.getElementById('history-body');
    body.innerHTML = '';
    
    // Kita flat history dari pemicu symbol
    let allTrades = [];
    Object.keys(mem.History).forEach(sym => {
        mem.History[sym].forEach(entry => {
            if (entry.res !== "PENDING") {
                allTrades.push(entry);
            }
        });
    });

    // Sort by timestamp descending
    allTrades.sort((a,b) => new Date(b.ts) - new Date(a.ts));

    allTrades.slice(0, 50).forEach(t => {
        const tr = document.createElement('tr');
        const pnlPct = (t.pnl / t.bal * 100).toFixed(2);
        const typeClass = t.type === 'BUY' ? 'type-buy' : 'type-sell';
        
        tr.innerHTML = `
            <td>${new Date(t.ts).toLocaleString('id-ID')}</td>
            <td>${t.sym}</td>
            <td class="mono">${t.ticket || '-'}</td>
            <td class="${typeClass}">${t.type || '-'}</td>
            <td class="mono">${t.vol || '-'}</td>
            <td class="mono">${(t.entry || 0).toFixed(5)}</td>
            <td class="mono">${(t.exit || 0).toFixed(5)}</td>
            <td class="mono ${t.pnl >= 0 ? 'success' : 'danger'}">${formatCurrency(t.pnl)}</td>
            <td class="mono ${pnlPct >= 0 ? 'success' : 'danger'}">${pnlPct}%</td>
        `;
        body.appendChild(tr);
    });
}

function renderLessons(listElId, data, isVictory) {
    const list = document.getElementById(listElId);
    list.innerHTML = '';
    if (!data || data.length === 0) {
        list.innerHTML = `<div class="lesson-item text-dim">No memory recorded.</div>`;
        return;
    }
    
    const sorted = [...data].reverse().slice(0, 10);
    sorted.forEach(l => {
        const item = document.createElement('div');
        item.className = 'lesson-item';
        item.innerHTML = `
            <div class="lesson-meta">
                <span>${l.symbol}</span>
                <span class="${isVictory ? 'success' : 'danger'}">${formatCurrency(l.pnl)}</span>
            </div>
            <div class="lesson-analysis" title="${l.analysis}">${l.analysis}</div>
        `;
        list.appendChild(item);
    });
}

async function refreshData() {
    try {
        const resp = await fetch('/api/stats');
        const data = await resp.json();

        // Update KPIs
        document.getElementById('kpi-equity').innerText = formatCurrency(data.equity);
        const fl = data.floating || 0;
        const flEl = document.getElementById('kpi-floating');
        flEl.innerText = (fl >= 0 ? '+' : '') + formatCurrency(fl);
        flEl.className = 'sub-value ' + (fl >= 0 ? 'success' : 'danger');

        document.getElementById('kpi-drawdown').innerText = formatCurrency(Math.abs(data.max_abs_drawdown));
        document.getElementById('kpi-total-pnl').innerText = (data.total_pnl >= 0 ? '+' : '') + formatCurrency(data.total_pnl);
        document.getElementById('kpi-total-pnl').className = 'value mono ' + (data.total_pnl >= 0 ? 'success' : 'danger');
        
        document.getElementById('kpi-winrate').innerText = (data.win_rate || 0).toFixed(1) + '%';
        
        // Status indicator
        const dot = document.getElementById('status-dot');
        dot.style.background = '#089981';
        document.getElementById('sync-status').innerText = 'CONNECTED';
        document.getElementById('last-update').innerText = new Date().toLocaleTimeString();

        // History Table
        // Kita butuh data mentah memory, atau kita modif /api/stats.
        // Asumsi data.latest_lessons atau data.history ada.
        // Di server.go, /api/stats tidak mengembalikan full memory. History select manual.
        // Mari kita fetch memory sekalian atau update /api/stats agar menyertakan data riwayat.
        // Untuk sekarang, kita hitung dari victories/disasters sebagai fallback.
        const memResp = await fetch('/api/stats'); // Re-fetch atau gunakan data yang ada
        // (Saya butuh memori mentah, saya akan update server.go untuk menyertakannya)
        
        renderHistoryTable({History: {all: [...(data.latest_lessons || []), ...(data.latest_disasters || [])]}});

        renderLessons('victories-list', data.latest_lessons, true);
        renderLessons('disasters-list', data.latest_disasters, false);

        // Chart
        if (data.chart_data && growthChart) {
            growthChart.data.labels = data.chart_data.map(d => d.date);
            growthChart.data.datasets[0].data = data.chart_data.map(d => d.val);
            growthChart.update();
        }

    } catch (e) {
        console.error("Dashboard Sync Error:", e);
        document.getElementById('status-dot').style.background = '#f23645';
        document.getElementById('sync-status').innerText = 'IDLE / ERROR';
    }
}

function initChart() {
    const ctx = document.getElementById('growthChart').getContext('2d');
    growthChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Cumulative PnL',
                data: [],
                borderColor: '#2962ff',
                backgroundColor: 'rgba(41, 98, 255, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.1,
                pointRadius: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                x: { grid: { display: false }, ticks: { color: '#787b86', font: { size: 10 } } },
                y: { grid: { color: '#1d222b' }, ticks: { color: '#787b86', font: { size: 10 } } }
            }
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    initChart();
    refreshData();
    setInterval(refreshData, 30000);
});
