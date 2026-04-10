let growthChart = null;

function formatMoney(amount) {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
}

function initChart() {
    const ctx = document.getElementById('growthChart').getContext('2d');
    
    // Gradient fill
    let gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(0, 240, 255, 0.4)');
    gradient.addColorStop(1, 'rgba(0, 240, 255, 0.0)');

    growthChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Cumulative PnL',
                data: [],
                borderColor: '#00F0FF',
                backgroundColor: gradient,
                borderWidth: 2,
                pointBackgroundColor: '#07090E',
                pointBorderColor: '#00F0FF',
                pointBorderWidth: 2,
                pointRadius: 4,
                pointHoverRadius: 6,
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
                    backgroundColor: 'rgba(20, 25, 40, 0.9)',
                    titleColor: '#8E9BAE',
                    bodyColor: '#fff',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 12,
                    displayColors: false,
                    callbacks: {
                        label: function(context) {
                            return formatMoney(context.parsed.y);
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: { color: '#8E9BAE' }
                },
                y: {
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: { color: '#8E9BAE', callback: (val) => '$' + val }
                }
            },
            interaction: {
                mode: 'nearest',
                axis: 'x',
                intersect: false
            }
        }
    });
}

function createLessonHTML(lesson, isVictory) {
    const cls = isVictory ? 'victory' : 'disaster';
    return `
        <div class="lesson-item ${cls}">
            <div class="lesson-meta">
                <span class="symbol">${lesson.symbol}</span>
                <span>${lesson.date}</span>
                <span>${formatMoney(lesson.pnl)}</span>
            </div>
            <div class="lesson-decision">${lesson.decision.split('|').slice(0, 4).join(' | ')}</div>
            <div class="lesson-analysis">${lesson.analysis}</div>
        </div>
    `;
}

async function fetchStats() {
    try {
        const response = await fetch('/api/stats');
        if (!response.ok) throw new Error('API Error');
        const data = await response.json();

        // Update KPIs
        document.getElementById('kpi-equity').innerText = formatMoney(data.equity);
        document.getElementById('kpi-balance').innerText = formatMoney(data.balance);
        
        const floatEl = document.getElementById('kpi-floating');
        floatEl.innerText = formatMoney(data.floating);
        floatEl.className = data.floating < 0 ? 'text-danger' : (data.floating > 0 ? 'text-success' : 'text-neutral');

        document.getElementById('kpi-drawdown').innerText = formatMoney(data.max_abs_drawdown);
        document.getElementById('kpi-wins').innerText = data.wins;
        document.getElementById('kpi-losses').innerText = data.losses;

        // Update Chart
        if (data.chart_data && growthChart) {
            growthChart.data.labels = data.chart_data.map(d => d.date);
            growthChart.data.datasets[0].data = data.chart_data.map(d => d.val);
            growthChart.update();
        }

        // Update Lessons
        const vicEl = document.getElementById('victories-list');
        if (data.latest_lessons && data.latest_lessons.length > 0) {
            vicEl.innerHTML = data.latest_lessons.reverse().slice(0, 10).map(l => createLessonHTML(l, true)).join('');
        } else {
            vicEl.innerHTML = '<p class="text-neutral">Belum ada victory map.</p>';
        }

        const disEl = document.getElementById('disasters-list');
        if (data.latest_disasters && data.latest_disasters.length > 0) {
            disEl.innerHTML = data.latest_disasters.map(l => createLessonHTML(l, false)).join('');
        } else {
            disEl.innerHTML = '<p class="text-neutral">Aman. Belum ada catatan disaster.</p>';
        }

        // Pulse dot
        const dot = document.querySelector('.dot');
        dot.style.animation = 'none';
        dot.offsetHeight; /* trigger reflow */
        dot.style.animation = 'blink 2s infinite';

    } catch (err) {
        console.error('Failed to fetch stats:', err);
    }
}

// Initial Boot
document.addEventListener('DOMContentLoaded', () => {
    initChart();
    fetchStats();
    // Auto-refresh every 60 seconds
    setInterval(fetchStats, 60000);
});
