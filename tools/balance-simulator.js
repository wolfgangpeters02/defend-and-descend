// Tab switching
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(tab.dataset.panel).classList.add('active');
    });
});

// Charts
let damageChart, hashRateChart, hashAccumChart, powerChart, threatChart, bossHpChart,
    componentCostChart, protoDpsChart, protoPowerEffChart, efficiencyChart,
    sectorCostChart, sectorBonusChart;

const chartDefaults = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { labels: { color: '#a1a1aa' } } },
    scales: {
        x: { ticks: { color: '#a1a1aa' }, grid: { color: '#27272a' } },
        y: { ticks: { color: '#a1a1aa' }, grid: { color: '#27272a' } }
    }
};

window.addEventListener('load', () => {
    initCharts();
    updateProtocolChart();
    updateHashChart();
    updatePowerChart();
    updateThreatChart();
    updateBossChart();
    updateComponentChart();
    updateProtocolCompare();
    updateEfficiencyChart();
    updateSectorChart();
});

function initCharts() {
    damageChart = new Chart(document.getElementById('damageChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Damage Multiplier', color: '#a1a1aa' } }
        }}
    });

    hashRateChart = new Chart(document.getElementById('hashRateChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'CPU Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Hash/sec', color: '#a1a1aa' } }
        }}
    });

    hashAccumChart = new Chart(document.getElementById('hashAccumChart'), {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Time (minutes)', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Total Hash', color: '#a1a1aa' } }
        }}
    });

    powerChart = new Chart(document.getElementById('powerChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'CPU Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Power (Watts)', color: '#a1a1aa' } }
        }}
    });

    threatChart = new Chart(document.getElementById('threatChart'), {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Threat Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Multiplier', color: '#a1a1aa' } }
        }}
    });

    bossHpChart = new Chart(document.getElementById('bossHpChart'), {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Wave Number', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Boss HP', color: '#a1a1aa' } }
        }}
    });

    componentCostChart = new Chart(document.getElementById('componentCostChart'), {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Upgrade Cost (Hash)', color: '#a1a1aa' } }
        }}
    });

    protoDpsChart = new Chart(document.getElementById('protoDpsChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Protocol', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'DPS', color: '#a1a1aa' } }
        }}
    });

    protoPowerEffChart = new Chart(document.getElementById('protoPowerEffChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Protocol', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'DPS per Watt', color: '#a1a1aa' } }
        }}
    });

    efficiencyChart = new Chart(document.getElementById('efficiencyChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'RAM Level', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Recovery Multiplier', color: '#a1a1aa' } }
        }}
    });

    sectorCostChart = new Chart(document.getElementById('sectorCostChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Sector', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Hash', color: '#a1a1aa' } }
        }}
    });

    sectorBonusChart = new Chart(document.getElementById('sectorBonusChart'), {
        type: 'bar',
        data: { labels: [], datasets: [] },
        options: { ...chartDefaults, scales: { ...chartDefaults.scales,
            x: { ...chartDefaults.scales.x, title: { display: true, text: 'Sector', color: '#a1a1aa' } },
            y: { ...chartDefaults.scales.y, title: { display: true, text: 'Hash Multiplier', color: '#a1a1aa' } }
        }}
    });
}

// ===== PROTOCOL LEVELING =====
function updateProtocolChart() {
    const maxLevel = parseInt(document.getElementById('proto-max-level').value);
    const dmgMult = parseFloat(document.getElementById('proto-dmg-mult').value);
    const costCommon = parseInt(document.getElementById('cost-common').value);
    const costRare = parseInt(document.getElementById('cost-rare').value);
    const costEpic = parseInt(document.getElementById('cost-epic').value);
    const costLegendary = parseInt(document.getElementById('cost-legendary').value);
    const formula = document.getElementById('cost-formula').value;

    const levels = [];
    const damages = [];

    for (let l = 1; l <= maxLevel; l++) {
        levels.push(l);
        damages.push(l * dmgMult); // Level multiplier = level number
    }

    document.getElementById('max-dmg-display').textContent = (maxLevel * dmgMult).toFixed(1) + 'x';

    damageChart.data.labels = levels;
    damageChart.data.datasets = [{
        label: 'Damage Multiplier',
        data: damages,
        backgroundColor: '#00d4ff',
        borderColor: '#00d4ff'
    }];
    damageChart.update();

    // Cost table
    const tbody = document.querySelector('#upgrade-cost-table tbody');
    tbody.innerHTML = '';

    const costs = { common: costCommon, rare: costRare, epic: costEpic, legendary: costLegendary };
    const totals = { common: 0, rare: 0, epic: 0, legendary: 0 };

    for (let l = 1; l <= maxLevel; l++) {
        const row = document.createElement('tr');
        const dmg = l * dmgMult;
        const prevDmg = l > 1 ? (l - 1) * dmgMult : 0;
        const dpsGain = l > 1 ? ((dmg - prevDmg) / prevDmg * 100).toFixed(0) : '-';

        let commonCost = 0, rareCost = 0, epicCost = 0, legendaryCost = 0;

        if (l > 1) {
            switch (formula) {
                case 'exponential':
                    commonCost = costCommon * Math.pow(2, l - 2);
                    rareCost = costRare * Math.pow(2, l - 2);
                    epicCost = costEpic * Math.pow(2, l - 2);
                    legendaryCost = costLegendary * Math.pow(2, l - 2);
                    break;
                case 'linear':
                    commonCost = costCommon * (l - 1);
                    rareCost = costRare * (l - 1);
                    epicCost = costEpic * (l - 1);
                    legendaryCost = costLegendary * (l - 1);
                    break;
                case 'quadratic':
                    commonCost = costCommon * Math.pow(l - 1, 2);
                    rareCost = costRare * Math.pow(l - 1, 2);
                    epicCost = costEpic * Math.pow(l - 1, 2);
                    legendaryCost = costLegendary * Math.pow(l - 1, 2);
                    break;
            }

            totals.common += commonCost;
            totals.rare += rareCost;
            totals.epic += epicCost;
            totals.legendary += legendaryCost;
        }

        row.innerHTML = `
            <td>${l}</td>
            <td class="rarity-common">${l === 1 ? '-' : Math.floor(commonCost).toLocaleString()}</td>
            <td class="rarity-rare">${l === 1 ? '-' : Math.floor(rareCost).toLocaleString()}</td>
            <td class="rarity-epic">${l === 1 ? '-' : Math.floor(epicCost).toLocaleString()}</td>
            <td class="rarity-legendary">${l === 1 ? '-' : Math.floor(legendaryCost).toLocaleString()}</td>
            <td class="highlight">${dmg.toFixed(1)}x</td>
            <td>${dpsGain}%</td>
        `;
        tbody.appendChild(row);
    }

    document.getElementById('total-cost-summary').innerHTML = `
        <li><span class="rarity-common">Common:</span> ${Math.floor(totals.common).toLocaleString()} Hash</li>
        <li><span class="rarity-rare">Rare:</span> ${Math.floor(totals.rare).toLocaleString()} Hash</li>
        <li><span class="rarity-epic">Epic:</span> ${Math.floor(totals.epic).toLocaleString()} Hash</li>
        <li><span class="rarity-legendary">Legendary:</span> ${Math.floor(totals.legendary).toLocaleString()} Hash</li>
    `;
}

// ===== HASH ECONOMY =====
function updateHashChart() {
    const base = parseFloat(document.getElementById('hash-base').value);
    const cpuMult = parseFloat(document.getElementById('hash-cpu-mult').value);
    const storageBase = parseInt(document.getElementById('storage-base').value);
    const storagePerLevel = parseInt(document.getElementById('storage-per-level').value);
    const maxTier = parseInt(document.getElementById('storage-max-tier').value);
    const offlineRate = parseFloat(document.getElementById('offline-rate').value) / 100;
    const maxOfflineHours = parseFloat(document.getElementById('offline-max-hours').value);

    // Hash rate by CPU level
    const levels = [];
    const rates = [];
    for (let l = 1; l <= 10; l++) {
        levels.push(l);
        rates.push(base * Math.pow(cpuMult, l - 1));
    }

    hashRateChart.data.labels = levels;
    hashRateChart.data.datasets = [{
        label: 'Hash/sec',
        data: rates,
        backgroundColor: '#00d4ff'
    }];
    hashRateChart.update();

    // Hash accumulation over time (comparing CPU levels 1, 3, 5, 7)
    const times = [];
    const data1 = [], data3 = [], data5 = [], data7 = [];
    const rate1 = base * Math.pow(cpuMult, 0);
    const rate3 = base * Math.pow(cpuMult, 2);
    const rate5 = base * Math.pow(cpuMult, 4);
    const rate7 = base * Math.pow(cpuMult, 6);

    for (let m = 0; m <= 10; m++) {
        times.push(m);
        data1.push(rate1 * m * 60);
        data3.push(rate3 * m * 60);
        data5.push(rate5 * m * 60);
        data7.push(rate7 * m * 60);
    }

    hashAccumChart.data.labels = times;
    hashAccumChart.data.datasets = [
        { label: 'CPU Lv1', data: data1, borderColor: '#71717a', fill: false },
        { label: 'CPU Lv3', data: data3, borderColor: '#3b82f6', fill: false },
        { label: 'CPU Lv5', data: data5, borderColor: '#a855f7', fill: false },
        { label: 'CPU Lv7', data: data7, borderColor: '#eab308', fill: false }
    ];
    hashAccumChart.update();

    // Storage table
    const tbody = document.querySelector('#storage-table tbody');
    tbody.innerHTML = '';

    for (let t = 1; t <= maxTier; t++) {
        const capacity = storageBase + (t - 1) * storagePerLevel;
        const fillTime = capacity / rate1;
        const offlineCap = Math.min(capacity, rate1 * offlineRate * maxOfflineHours * 3600);

        tbody.innerHTML += `
            <tr>
                <td>Tier ${t}</td>
                <td class="highlight">${capacity.toLocaleString()}</td>
                <td>${formatTime(fillTime)}</td>
                <td>${Math.floor(offlineCap).toLocaleString()}</td>
            </tr>
        `;
    }

    // Offline summary
    document.getElementById('offline-summary').innerHTML = `
        <li>8h offline @ CPU Lv1: ${Math.floor(rate1 * offlineRate * 8 * 3600).toLocaleString()} Hash (${(offlineRate * 100).toFixed(0)}% rate)</li>
        <li>8h offline @ CPU Lv5: ${Math.floor(rate5 * offlineRate * 8 * 3600).toLocaleString()} Hash</li>
        <li>Overclock bonus: ${(parseFloat(document.getElementById('overclock-mult').value) * 100).toFixed(0)}% for ${document.getElementById('overclock-duration').value}s</li>
    `;
}

// ===== POWER GRID =====
function updatePowerChart() {
    const basePower = parseInt(document.getElementById('power-base').value);
    const powerPerLevel = parseInt(document.getElementById('power-per-level').value);
    const maxCPU = parseInt(document.getElementById('power-max-cpu').value);
    const towerCommon = parseInt(document.getElementById('tower-power-common').value);
    const towerRare = parseInt(document.getElementById('tower-power-rare').value);
    const towerEpic = parseInt(document.getElementById('tower-power-epic').value);
    const towerLegendary = parseInt(document.getElementById('tower-power-legendary').value);

    const levels = [];
    const powerBudgets = [];

    for (let l = 1; l <= maxCPU; l++) {
        levels.push(l);
        powerBudgets.push(basePower + l * powerPerLevel);
    }

    powerChart.data.labels = levels;
    powerChart.data.datasets = [{
        label: 'Power Budget (W)',
        data: powerBudgets,
        backgroundColor: '#22c55e'
    }];
    powerChart.update();

    // Tower limit table
    const tbody = document.querySelector('#tower-limit-table tbody');
    tbody.innerHTML = '';

    for (let l = 1; l <= maxCPU; l++) {
        const budget = basePower + l * powerPerLevel;
        tbody.innerHTML += `
            <tr>
                <td>CPU ${l}</td>
                <td class="highlight">${budget}W</td>
                <td class="rarity-common">${Math.floor(budget / towerCommon)}</td>
                <td class="rarity-rare">${Math.floor(budget / towerRare)}</td>
                <td class="rarity-epic">${Math.floor(budget / towerEpic)}</td>
                <td class="rarity-legendary">${Math.floor(budget / towerLegendary)}</td>
            </tr>
        `;
    }
}

// ===== THREAT SYSTEM =====
function updateThreatChart() {
    const onlineRate = parseFloat(document.getElementById('threat-online-rate').value);
    const hpScale = parseFloat(document.getElementById('threat-hp-scale').value);
    const speedScale = parseFloat(document.getElementById('threat-speed-scale').value);
    const dmgScale = parseFloat(document.getElementById('threat-dmg-scale').value);
    const maxThreat = parseInt(document.getElementById('threat-max').value);

    const unlockFast = parseFloat(document.getElementById('unlock-fast').value);
    const unlockSwarm = parseFloat(document.getElementById('unlock-swarm').value);
    const unlockTank = parseFloat(document.getElementById('unlock-tank').value);
    const unlockElite = parseFloat(document.getElementById('unlock-elite').value);
    const unlockBoss = parseFloat(document.getElementById('unlock-boss').value);

    const threats = [];
    const hpData = [], speedData = [], dmgData = [];

    const displayMax = Math.min(maxThreat, 30);
    for (let t = 1; t <= displayMax; t++) {
        threats.push(t);
        hpData.push(1 + (t - 1) * hpScale);
        speedData.push(1 + (t - 1) * speedScale);
        dmgData.push(1 + (t - 1) * dmgScale);
    }

    threatChart.data.labels = threats;
    threatChart.data.datasets = [
        { label: 'HP Multiplier', data: hpData, borderColor: '#ef4444', fill: false },
        { label: 'Speed Multiplier', data: speedData, borderColor: '#22c55e', fill: false },
        { label: 'Damage Multiplier', data: dmgData, borderColor: '#eab308', fill: false }
    ];
    threatChart.update();

    // Timeline table
    const tbody = document.querySelector('#threat-timeline-table tbody');
    tbody.innerHTML = '';

    const events = [
        { name: 'Fast Enemy', threat: unlockFast },
        { name: 'Swarm Enemy', threat: unlockSwarm },
        { name: 'Tank Enemy', threat: unlockTank },
        { name: 'Elite Enemy', threat: unlockElite },
        { name: 'Mini-Boss', threat: unlockBoss }
    ];

    events.forEach(e => {
        const time = e.threat / onlineRate;
        const hp = 1 + (e.threat - 1) * hpScale;
        const spd = 1 + (e.threat - 1) * speedScale;
        const dmg = 1 + (e.threat - 1) * dmgScale;

        tbody.innerHTML += `
            <tr>
                <td>${e.name}</td>
                <td class="highlight">${e.threat}</td>
                <td>${formatTime(time)}</td>
                <td>${hp.toFixed(2)}x</td>
                <td>${spd.toFixed(2)}x</td>
                <td>${dmg.toFixed(2)}x</td>
            </tr>
        `;
    });
}

// ===== BOSS TUNING =====
function updateBossChart() {
    const baseHp = parseInt(document.getElementById('cyber-hp').value);
    const hpScale = parseFloat(document.getElementById('cyber-hp-scale').value);
    const laserDmg = parseInt(document.getElementById('cyber-laser-dmg').value);
    const laserWarn = parseFloat(document.getElementById('cyber-laser-warn').value);
    const puddleDmg = parseInt(document.getElementById('cyber-puddle-dmg').value);
    const puddleDur = parseFloat(document.getElementById('cyber-puddle-dur').value);
    const spawnCount = parseInt(document.getElementById('cyber-spawn-count').value);
    const spawnInterval = parseInt(document.getElementById('cyber-spawn-interval').value);

    const phase2 = parseInt(document.getElementById('cyber-phase2').value);
    const phase3 = parseInt(document.getElementById('cyber-phase3').value);
    const phase4 = parseInt(document.getElementById('cyber-phase4').value);

    // Boss HP by wave (boss appears every 5 waves)
    const waves = [];
    const hpData = [];

    for (let w = 5; w <= 30; w += 5) {
        waves.push(w);
        hpData.push(baseHp * (1 + (w - 1) * hpScale));
    }

    bossHpChart.data.labels = waves;
    bossHpChart.data.datasets = [{
        label: 'Cyberboss HP',
        data: hpData,
        borderColor: '#ef4444',
        backgroundColor: 'rgba(239,68,68,0.1)',
        fill: true
    }];
    bossHpChart.update();

    // Update phase timeline
    document.querySelector('.phase-timeline').innerHTML = `
        <div class="phase-block">
            <div class="phase-name">Phase 1</div>
            <div class="phase-hp">100% - ${phase2 + 1}%</div>
        </div>
        <div class="phase-block">
            <div class="phase-name">Phase 2</div>
            <div class="phase-hp">${phase2}% - ${phase3 + 1}%</div>
        </div>
        <div class="phase-block">
            <div class="phase-name">Phase 3</div>
            <div class="phase-hp">${phase3}% - ${phase4 + 1}%</div>
        </div>
        <div class="phase-block">
            <div class="phase-name">Phase 4</div>
            <div class="phase-hp">${phase4}% - 0%</div>
        </div>
    `;

    // Ability table
    document.getElementById('boss-ability-table').innerHTML = `
        <tr>
            <td>Laser Beam</td>
            <td class="danger">${laserDmg} (instant)</td>
            <td>${laserWarn}s warning</td>
            <td>High - avoid or die</td>
        </tr>
        <tr>
            <td>Acid Puddle</td>
            <td class="warning">${puddleDmg}/sec</td>
            <td>${puddleDur}s duration</td>
            <td>Medium - zone denial</td>
        </tr>
        <tr>
            <td>Spawn Adds</td>
            <td>${spawnCount} enemies</td>
            <td>Every ${spawnInterval}s</td>
            <td>Low - distraction</td>
        </tr>
    `;
}

// ===== COMPONENT UPGRADES =====
function updateComponentChart() {
    const maxLevel = parseInt(document.getElementById('comp-max-level').value);
    const compIds = ['psu', 'ram', 'gpu', 'cache', 'storage', 'expansion', 'network', 'io', 'cpu'];
    const compNames = ['PSU', 'RAM', 'GPU', 'Cache', 'Storage', 'Expansion', 'Network', 'I/O', 'CPU'];
    const compColors = ['#22c55e', '#3b82f6', '#ef4444', '#eab308', '#a855f7', '#f97316', '#06b6d4', '#ec4899', '#00d4ff'];

    const baseCosts = {};
    compIds.forEach(id => {
        baseCosts[id] = parseInt(document.getElementById('comp-cost-' + id).value);
    });

    // PSU capacity table (fixed values from BalanceConfig)
    const psuCapacities = [300, 400, 550, 700, 900, 1100, 1350, 1600, 1900, 2300];

    // Cost curves chart
    const levels = [];
    for (let l = 1; l <= maxLevel; l++) levels.push(l);

    const datasets = compIds.map((id, i) => {
        const data = levels.map(l => l === 1 ? 0 : baseCosts[id] * Math.pow(2, l - 2));
        return {
            label: compNames[i],
            data: data,
            borderColor: compColors[i],
            fill: false,
            tension: 0.1
        };
    });

    componentCostChart.data.labels = levels;
    componentCostChart.data.datasets = datasets;
    componentCostChart.update();

    // Stat progression table
    const tbody = document.querySelector('#component-stat-table tbody');
    tbody.innerHTML = '';

    for (let l = 1; l <= maxLevel; l++) {
        const psuW = l <= psuCapacities.length ? psuCapacities[l - 1] : psuCapacities[psuCapacities.length - 1];
        const gpuMult = (1.0 + (l - 1) * 0.055).toFixed(2);
        const cacheMult = (1.0 + (l - 1) * 0.033).toFixed(2);
        const ramRegen = (1.0 + (l - 1) * 0.111).toFixed(2);
        const netMult = (1.0 + (l - 1) * 0.055).toFixed(2);
        const ioMult = (1.0 + (l - 1) * 0.167).toFixed(2);
        const storageCap = Math.floor(25000 * Math.pow(2, l - 1)).toLocaleString();
        const expSlots = l >= 7 ? '+2' : (l >= 4 ? '+1' : '0');

        tbody.innerHTML += `
            <tr>
                <td>${l}</td>
                <td class="highlight">${psuW}W</td>
                <td>${gpuMult}×</td>
                <td>${cacheMult}×</td>
                <td>${ramRegen}×</td>
                <td>${netMult}×</td>
                <td>${ioMult}×</td>
                <td>${storageCap}</td>
                <td>${expSlots}</td>
            </tr>
        `;
    }

    // Total cost summary
    const totalCostSummary = document.getElementById('comp-total-cost-summary');
    totalCostSummary.innerHTML = '';
    compIds.forEach((id, i) => {
        let total = 0;
        for (let l = 2; l <= maxLevel; l++) {
            total += baseCosts[id] * Math.pow(2, l - 2);
        }
        totalCostSummary.innerHTML += `<li><span style="color:${compColors[i]}">${compNames[i]}:</span> ${Math.floor(total).toLocaleString()} Hash (base: ${baseCosts[id]})</li>`;
    });
}

// ===== PROTOCOL COMPARISON =====
const PROTOCOLS = [
    { name: 'Kernel Pulse', rarity: 'Common', fwDmg: 8, fwRate: 1.0, fwRange: 120, fwProj: 1, fwPierce: 1, fwSplash: 0, power: 15, wpDmg: 8, wpRate: 2.0, wpProj: 1, compileCost: 0, upgradeCost: 50, fwSpecial: '-', wpSpecial: '-' },
    { name: 'Burst Protocol', rarity: 'Common', fwDmg: 10, fwRate: 0.8, fwRange: 140, fwProj: 1, fwPierce: 1, fwSplash: 40, power: 20, wpDmg: 6, wpRate: 0.8, wpProj: 5, compileCost: 100, upgradeCost: 50, fwSpecial: 'Splash (40r)', wpSpecial: 'Spread (5 proj)' },
    { name: 'Trace Route', rarity: 'Rare', fwDmg: 50, fwRate: 0.4, fwRange: 250, fwProj: 1, fwPierce: 3, fwSplash: 0, power: 35, wpDmg: 40, wpRate: 0.5, wpProj: 1, compileCost: 200, upgradeCost: 100, fwSpecial: 'Pierce (3)', wpSpecial: 'Pierce (5)' },
    { name: 'Ice Shard', rarity: 'Rare', fwDmg: 5, fwRate: 1.5, fwRange: 130, fwProj: 1, fwPierce: 1, fwSplash: 0, power: 30, wpDmg: 4, wpRate: 3.0, wpProj: 1, compileCost: 200, upgradeCost: 100, fwSpecial: 'Slow (50%, 2s)', wpSpecial: 'Slow (50%, 2s)' },
    { name: 'Fork Bomb', rarity: 'Epic', fwDmg: 12, fwRate: 0.7, fwRange: 140, fwProj: 3, fwPierce: 1, fwSplash: 0, power: 40, wpDmg: 10, wpRate: 1.0, wpProj: 8, compileCost: 400, upgradeCost: 200, fwSpecial: 'Multi (3 proj)', wpSpecial: 'Multi (8 proj)' },
    { name: 'Root Access', rarity: 'Epic', fwDmg: 80, fwRate: 0.3, fwRange: 160, fwProj: 1, fwPierce: 1, fwSplash: 0, power: 75, wpDmg: 60, wpRate: 0.4, wpProj: 1, compileCost: 400, upgradeCost: 200, fwSpecial: 'Pure damage', wpSpecial: 'Pure damage' },
    { name: 'Overflow', rarity: 'Legendary', fwDmg: 15, fwRate: 0.8, fwRange: 150, fwProj: 1, fwPierce: 1, fwSplash: 0, power: 120, wpDmg: 12, wpRate: 1.2, wpProj: 1, compileCost: 800, upgradeCost: 400, fwSpecial: 'Chain (3 targets)', wpSpecial: 'Ricochet (3 bounces)' },
    { name: 'Null Pointer', rarity: 'Legendary', fwDmg: 25, fwRate: 0.6, fwRange: 140, fwProj: 1, fwPierce: 1, fwSplash: 0, power: 100, wpDmg: 20, wpRate: 0.8, wpProj: 1, compileCost: 800, upgradeCost: 400, fwSpecial: 'Execute (low HP)', wpSpecial: 'Critical (2× chance)' }
];

const rarityColors = { 'Common': '#a1a1aa', 'Rare': '#3b82f6', 'Epic': '#a855f7', 'Legendary': '#eab308' };

function updateProtocolCompare() {
    const level = parseInt(document.getElementById('proto-compare-level').value);
    document.getElementById('proto-compare-level-display').textContent = 'Lv ' + level;

    const dmgMult = level; // levelStatMultiplier = level number

    // Firewall table
    const fwBody = document.querySelector('#proto-firewall-table tbody');
    fwBody.innerHTML = '';
    const dpsValues = [];
    const dpsPerWatt = [];
    const names = [];

    PROTOCOLS.forEach(p => {
        const dmg = p.fwDmg * dmgMult;
        const dps = dmg * p.fwRate * p.fwProj;
        dpsValues.push(dps);
        dpsPerWatt.push(dps / p.power);
        names.push(p.name);

        fwBody.innerHTML += `
            <tr>
                <td>${p.name}</td>
                <td style="color:${rarityColors[p.rarity]}">${p.rarity}</td>
                <td>${dmg}</td>
                <td>${p.fwRate}/s</td>
                <td>${p.fwRange}</td>
                <td class="highlight">${dps.toFixed(1)}</td>
                <td>${p.power}W</td>
                <td>${(dps / p.power).toFixed(2)}</td>
                <td>${p.fwSpecial}</td>
            </tr>
        `;
    });

    // Weapon table
    const wpBody = document.querySelector('#proto-weapon-table tbody');
    wpBody.innerHTML = '';

    PROTOCOLS.forEach(p => {
        const dmg = p.wpDmg * dmgMult;
        const dps = dmg * p.wpRate * p.wpProj;

        wpBody.innerHTML += `
            <tr>
                <td>${p.name}</td>
                <td style="color:${rarityColors[p.rarity]}">${p.rarity}</td>
                <td>${dmg}</td>
                <td>${p.wpRate}/s</td>
                <td>${p.wpProj}</td>
                <td class="highlight">${dps.toFixed(1)}</td>
                <td>${p.wpSpecial}</td>
            </tr>
        `;
    });

    // DPS chart
    protoDpsChart.data.labels = names;
    protoDpsChart.data.datasets = [{
        label: 'Firewall DPS (Lv ' + level + ')',
        data: dpsValues,
        backgroundColor: PROTOCOLS.map(p => rarityColors[p.rarity])
    }];
    protoDpsChart.update();

    // DPS/Watt chart
    protoPowerEffChart.data.labels = names;
    protoPowerEffChart.data.datasets = [{
        label: 'DPS per Watt (Lv ' + level + ')',
        data: dpsPerWatt,
        backgroundColor: PROTOCOLS.map(p => rarityColors[p.rarity])
    }];
    protoPowerEffChart.update();

    // Cost table
    const costBody = document.querySelector('#proto-cost-table tbody');
    costBody.innerHTML = '';

    PROTOCOLS.forEach(p => {
        let totalUpgrade = 0;
        for (let l = 2; l <= 10; l++) {
            totalUpgrade += p.upgradeCost * Math.pow(2, l - 2);
        }
        const dpsLv10 = p.fwDmg * 10 * p.fwRate * p.fwProj;
        const totalCost = p.compileCost + totalUpgrade;
        const hashPerDps = dpsLv10 > 0 ? (totalCost / dpsLv10).toFixed(1) : '-';

        costBody.innerHTML += `
            <tr>
                <td>${p.name}</td>
                <td style="color:${rarityColors[p.rarity]}">${p.rarity}</td>
                <td>${p.compileCost.toLocaleString()}</td>
                <td>${p.upgradeCost}</td>
                <td class="highlight">${totalCost.toLocaleString()}</td>
                <td>${dpsLv10.toFixed(1)}</td>
                <td>${hashPerDps}</td>
            </tr>
        `;
    });
}

// ===== EFFICIENCY / FREEZE =====
function updateEfficiencyChart() {
    const leakInterval = parseFloat(document.getElementById('eff-leak-interval').value);
    const warningPct = parseInt(document.getElementById('eff-warning').value);
    const freezeCostPct = parseInt(document.getElementById('freeze-cost-pct').value);
    const freezeTargetEff = parseInt(document.getElementById('freeze-target-eff').value);
    const ramBaseRegen = parseFloat(document.getElementById('ram-base-regen').value);
    const ramRegenPerLevel = parseFloat(document.getElementById('ram-regen-per-level').value);

    // RAM recovery chart
    const levels = [];
    const regenValues = [];
    for (let l = 1; l <= 10; l++) {
        levels.push(l);
        regenValues.push(ramBaseRegen + (l - 1) * ramRegenPerLevel);
    }

    efficiencyChart.data.labels = levels;
    efficiencyChart.data.datasets = [{
        label: 'Recovery Multiplier',
        data: regenValues,
        backgroundColor: '#22c55e'
    }];
    efficiencyChart.update();

    // Freeze cost table
    const freezeBody = document.querySelector('#freeze-cost-table tbody');
    freezeBody.innerHTML = '';
    const hashAmounts = [1000, 5000, 10000, 25000, 50000, 100000, 250000, 500000];

    hashAmounts.forEach(hash => {
        const cost = Math.floor(hash / (100 / freezeCostPct));
        freezeBody.innerHTML += `
            <tr>
                <td>${hash.toLocaleString()} Ħ</td>
                <td class="warning">${cost.toLocaleString()} Ħ</td>
                <td>${freezeTargetEff}%</td>
            </tr>
        `;
    });

    // Decay timeline table
    const decayBody = document.querySelector('#eff-decay-table tbody');
    decayBody.innerHTML = '';
    const leakRates = [1, 2, 3, 5, 10];

    leakRates.forEach(leaksPerMin => {
        // Each leak at leakInterval reduces efficiency
        // Simplified model: efficiency drops by ~5% per leak event
        const effLossPerLeak = 5; // approximate % loss per leak
        const leaksToWarning = Math.ceil((100 - warningPct) / effLossPerLeak);
        const leaksToFreeze = Math.ceil(100 / effLossPerLeak);
        const timeToWarning = leaksToWarning / leaksPerMin * 60;
        const timeToFreeze = leaksToFreeze / leaksPerMin * 60;

        // RAM extends survival by slowing net loss (regen counteracts decay)
        const ramLv5Regen = ramBaseRegen + 4 * ramRegenPerLevel;
        const ramLv10Regen = ramBaseRegen + 9 * ramRegenPerLevel;
        const timeFreezeRam5 = timeToFreeze * ramLv5Regen;
        const timeFreezeRam10 = timeToFreeze * ramLv10Regen;

        decayBody.innerHTML += `
            <tr>
                <td>${leaksPerMin}/min</td>
                <td>${formatTime(timeToWarning)}</td>
                <td class="danger">${formatTime(timeToFreeze)}</td>
                <td>${formatTime(timeFreezeRam5)}</td>
                <td class="highlight">${formatTime(timeFreezeRam10)}</td>
            </tr>
        `;
    });
}

// ===== SECTOR PROGRESSION =====
const SECTOR_NAMES = ['PSU', 'RAM', 'GPU', 'Cache', 'Storage', 'Expansion', 'Network', 'I/O', 'CPU'];
const SECTOR_HASH_BONUS = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0];

function updateSectorChart() {
    const costs = [];
    for (let i = 0; i < 9; i++) {
        costs.push(parseInt(document.getElementById('sector-cost-' + i).value) || 0);
    }

    // Cumulative costs
    const cumulative = [];
    let running = 0;
    costs.forEach(c => {
        running += c;
        cumulative.push(running);
    });

    // Cost chart (stacked: individual + cumulative line)
    sectorCostChart.data.labels = SECTOR_NAMES;
    sectorCostChart.data.datasets = [
        {
            label: 'Unlock Cost',
            data: costs,
            backgroundColor: '#00d4ff',
            order: 2
        },
        {
            label: 'Cumulative',
            data: cumulative,
            type: 'line',
            borderColor: '#ef4444',
            backgroundColor: 'rgba(239,68,68,0.1)',
            fill: true,
            order: 1
        }
    ];
    sectorCostChart.update();

    // Hash bonus chart
    sectorBonusChart.data.labels = SECTOR_NAMES;
    sectorBonusChart.data.datasets = [{
        label: 'Hash Multiplier',
        data: SECTOR_HASH_BONUS,
        backgroundColor: SECTOR_HASH_BONUS.map(v =>
            v >= 2.5 ? '#eab308' : v >= 2.0 ? '#a855f7' : v >= 1.4 ? '#3b82f6' : '#22c55e'
        )
    }];
    sectorBonusChart.update();

    // Timeline table
    const tbody = document.querySelector('#sector-timeline-table tbody');
    tbody.innerHTML = '';

    const hashRates = [1, 5, 38]; // CPU Lv1, ~Lv5, Lv10

    costs.forEach((cost, i) => {
        const cum = cumulative[i];
        const bonus = SECTOR_HASH_BONUS[i];

        const times = hashRates.map(rate => cost > 0 ? formatTime(cost / rate) : '-');

        tbody.innerHTML += `
            <tr>
                <td>${SECTOR_NAMES[i]}</td>
                <td>${cost > 0 ? cost.toLocaleString() : 'Free'}</td>
                <td class="highlight">${cum.toLocaleString()}</td>
                <td>${bonus.toFixed(1)}×</td>
                <td>${times[0]}</td>
                <td>${times[1]}</td>
                <td>${times[2]}</td>
            </tr>
        `;
    });
}

// ===== EXPORT/IMPORT =====
function generateExport() {
    const config = {
        protocolScaling: {
            damageMultiplierPerLevel: parseFloat(document.getElementById('proto-dmg-mult').value),
            rangePerLevel: parseFloat(document.getElementById('proto-range-mult').value),
            fireRatePerLevel: parseFloat(document.getElementById('proto-fire-mult').value),
            maxLevel: parseInt(document.getElementById('proto-max-level').value),
            upgradeCostFormula: document.getElementById('cost-formula').value,
            baseCosts: {
                common: parseInt(document.getElementById('cost-common').value),
                rare: parseInt(document.getElementById('cost-rare').value),
                epic: parseInt(document.getElementById('cost-epic').value),
                legendary: parseInt(document.getElementById('cost-legendary').value)
            }
        },
        hashEconomy: {
            baseHashPerSecond: parseFloat(document.getElementById('hash-base').value),
            cpuLevelMultiplier: parseFloat(document.getElementById('hash-cpu-mult').value),
            baseStorageCapacity: parseInt(document.getElementById('storage-base').value),
            storagePerUpgrade: parseInt(document.getElementById('storage-per-level').value),
            overclockMultiplier: parseFloat(document.getElementById('overclock-mult').value),
            overclockDuration: parseInt(document.getElementById('overclock-duration').value),
            offlineEarningsRate: parseFloat(document.getElementById('offline-rate').value) / 100,
            maxOfflineHours: parseFloat(document.getElementById('offline-max-hours').value)
        },
        powerGrid: {
            basePowerBudget: parseInt(document.getElementById('power-base').value),
            powerPerCPULevel: parseInt(document.getElementById('power-per-level').value),
            towerPowerDraw: {
                common: parseInt(document.getElementById('tower-power-common').value),
                rare: parseInt(document.getElementById('tower-power-rare').value),
                epic: parseInt(document.getElementById('tower-power-epic').value),
                legendary: parseInt(document.getElementById('tower-power-legendary').value)
            },
            overclockPowerMultiplier: parseFloat(document.getElementById('overclock-power-mult').value)
        },
        threatLevel: {
            onlineGrowthRate: parseFloat(document.getElementById('threat-online-rate').value),
            offlineGrowthRate: parseFloat(document.getElementById('threat-offline-rate').value),
            healthScaling: parseFloat(document.getElementById('threat-hp-scale').value),
            speedScaling: parseFloat(document.getElementById('threat-speed-scale').value),
            damageScaling: parseFloat(document.getElementById('threat-dmg-scale').value),
            maxThreatLevel: parseInt(document.getElementById('threat-max').value),
            enemyUnlocks: {
                fast: parseFloat(document.getElementById('unlock-fast').value),
                swarm: parseFloat(document.getElementById('unlock-swarm').value),
                tank: parseFloat(document.getElementById('unlock-tank').value),
                elite: parseFloat(document.getElementById('unlock-elite').value),
                boss: parseFloat(document.getElementById('unlock-boss').value)
            }
        },
        cyberboss: {
            baseHP: parseInt(document.getElementById('cyber-hp').value),
            hpScalingPerWave: parseFloat(document.getElementById('cyber-hp-scale').value),
            laserDamage: parseInt(document.getElementById('cyber-laser-dmg').value),
            laserWarningDuration: parseFloat(document.getElementById('cyber-laser-warn').value),
            puddleDamagePerSecond: parseInt(document.getElementById('cyber-puddle-dmg').value),
            puddleDuration: parseFloat(document.getElementById('cyber-puddle-dur').value),
            spawnWaveSize: parseInt(document.getElementById('cyber-spawn-count').value),
            spawnInterval: parseInt(document.getElementById('cyber-spawn-interval').value),
            phaseThresholds: {
                phase2: parseInt(document.getElementById('cyber-phase2').value) / 100,
                phase3: parseInt(document.getElementById('cyber-phase3').value) / 100,
                phase4: parseInt(document.getElementById('cyber-phase4').value) / 100
            }
        },
        zeroDay: {
            baseHP: parseInt(document.getElementById('zeroday-hp').value),
            speed: parseInt(document.getElementById('zeroday-speed').value),
            efficiencyDrainRate: parseFloat(document.getElementById('zeroday-drain').value),
            minWavesBeforeSpawn: parseInt(document.getElementById('zeroday-min-waves').value),
            defeatHashBonus: parseInt(document.getElementById('zeroday-hash').value),
            defeatEfficiencyRestore: parseInt(document.getElementById('zeroday-restore').value)
        },
        components: {
            maxLevel: parseInt(document.getElementById('comp-max-level').value),
            baseCosts: {
                psu: parseInt(document.getElementById('comp-cost-psu').value),
                ram: parseInt(document.getElementById('comp-cost-ram').value),
                gpu: parseInt(document.getElementById('comp-cost-gpu').value),
                cache: parseInt(document.getElementById('comp-cost-cache').value),
                storage: parseInt(document.getElementById('comp-cost-storage').value),
                expansion: parseInt(document.getElementById('comp-cost-expansion').value),
                network: parseInt(document.getElementById('comp-cost-network').value),
                io: parseInt(document.getElementById('comp-cost-io').value),
                cpu: parseInt(document.getElementById('comp-cost-cpu').value)
            }
        },
        efficiency: {
            leakDecayInterval: parseFloat(document.getElementById('eff-leak-interval').value),
            warningThreshold: parseInt(document.getElementById('eff-warning').value),
            freezeRecoveryCostPct: parseInt(document.getElementById('freeze-cost-pct').value),
            freezeRecoveryTarget: parseInt(document.getElementById('freeze-target-eff').value),
            ramBaseRegen: parseFloat(document.getElementById('ram-base-regen').value),
            ramRegenPerLevel: parseFloat(document.getElementById('ram-regen-per-level').value)
        },
        sectorUnlock: {
            hashCosts: Array.from({length: 9}, (_, i) => parseInt(document.getElementById('sector-cost-' + i).value) || 0),
            hashBonusMultipliers: SECTOR_HASH_BONUS
        }
    };

    document.getElementById('export-json').value = JSON.stringify(config, null, 2);
}

function importConfig() {
    try {
        const config = JSON.parse(document.getElementById('import-json').value);

        if (config.protocolScaling) {
            document.getElementById('proto-dmg-mult').value = config.protocolScaling.damageMultiplierPerLevel ?? 1.0;
            document.getElementById('proto-range-mult').value = config.protocolScaling.rangePerLevel ?? 0.05;
            document.getElementById('proto-fire-mult').value = config.protocolScaling.fireRatePerLevel ?? 0.03;
            document.getElementById('proto-max-level').value = config.protocolScaling.maxLevel ?? 10;
            document.getElementById('cost-formula').value = config.protocolScaling.upgradeCostFormula ?? 'exponential';
            if (config.protocolScaling.baseCosts) {
                document.getElementById('cost-common').value = config.protocolScaling.baseCosts.common ?? 50;
                document.getElementById('cost-rare').value = config.protocolScaling.baseCosts.rare ?? 100;
                document.getElementById('cost-epic').value = config.protocolScaling.baseCosts.epic ?? 200;
                document.getElementById('cost-legendary').value = config.protocolScaling.baseCosts.legendary ?? 400;
            }
        }

        if (config.hashEconomy) {
            document.getElementById('hash-base').value = config.hashEconomy.baseHashPerSecond ?? 1.0;
            document.getElementById('hash-cpu-mult').value = config.hashEconomy.cpuLevelMultiplier ?? 1.5;
            document.getElementById('storage-base').value = config.hashEconomy.baseStorageCapacity ?? 500;
            document.getElementById('storage-per-level').value = config.hashEconomy.storagePerUpgrade ?? 500;
            document.getElementById('overclock-mult').value = config.hashEconomy.overclockMultiplier ?? 2.0;
            document.getElementById('overclock-duration').value = config.hashEconomy.overclockDuration ?? 60;
            document.getElementById('offline-rate').value = (config.hashEconomy.offlineEarningsRate ?? 0.2) * 100;
            document.getElementById('offline-max-hours').value = config.hashEconomy.maxOfflineHours ?? 8;
        }

        if (config.powerGrid) {
            document.getElementById('power-base').value = config.powerGrid.basePowerBudget ?? 100;
            document.getElementById('power-per-level').value = config.powerGrid.powerPerCPULevel ?? 50;
            document.getElementById('overclock-power-mult').value = config.powerGrid.overclockPowerMultiplier ?? 2.0;
            if (config.powerGrid.towerPowerDraw) {
                document.getElementById('tower-power-common').value = config.powerGrid.towerPowerDraw.common ?? 15;
                document.getElementById('tower-power-rare').value = config.powerGrid.towerPowerDraw.rare ?? 30;
                document.getElementById('tower-power-epic').value = config.powerGrid.towerPowerDraw.epic ?? 60;
                document.getElementById('tower-power-legendary').value = config.powerGrid.towerPowerDraw.legendary ?? 100;
            }
        }

        if (config.threatLevel) {
            document.getElementById('threat-online-rate').value = config.threatLevel.onlineGrowthRate ?? 0.01;
            document.getElementById('threat-offline-rate').value = config.threatLevel.offlineGrowthRate ?? 0.001;
            document.getElementById('threat-hp-scale').value = config.threatLevel.healthScaling ?? 0.15;
            document.getElementById('threat-speed-scale').value = config.threatLevel.speedScaling ?? 0.02;
            document.getElementById('threat-dmg-scale').value = config.threatLevel.damageScaling ?? 0.05;
            document.getElementById('threat-max').value = config.threatLevel.maxThreatLevel ?? 100;
            if (config.threatLevel.enemyUnlocks) {
                document.getElementById('unlock-fast').value = config.threatLevel.enemyUnlocks.fast ?? 2.0;
                document.getElementById('unlock-swarm').value = config.threatLevel.enemyUnlocks.swarm ?? 4.0;
                document.getElementById('unlock-tank').value = config.threatLevel.enemyUnlocks.tank ?? 5.0;
                document.getElementById('unlock-elite').value = config.threatLevel.enemyUnlocks.elite ?? 8.0;
                document.getElementById('unlock-boss').value = config.threatLevel.enemyUnlocks.boss ?? 10.0;
            }
        }

        if (config.cyberboss) {
            document.getElementById('cyber-hp').value = config.cyberboss.baseHP ?? 5000;
            document.getElementById('cyber-hp-scale').value = config.cyberboss.hpScalingPerWave ?? 0.15;
            document.getElementById('cyber-laser-dmg').value = config.cyberboss.laserDamage ?? 50;
            document.getElementById('cyber-laser-warn').value = config.cyberboss.laserWarningDuration ?? 1.5;
            document.getElementById('cyber-puddle-dmg').value = config.cyberboss.puddleDamagePerSecond ?? 20;
            document.getElementById('cyber-puddle-dur').value = config.cyberboss.puddleDuration ?? 5.0;
            document.getElementById('cyber-spawn-count').value = config.cyberboss.spawnWaveSize ?? 5;
            document.getElementById('cyber-spawn-interval').value = config.cyberboss.spawnInterval ?? 8;
            if (config.cyberboss.phaseThresholds) {
                document.getElementById('cyber-phase2').value = (config.cyberboss.phaseThresholds.phase2 ?? 0.75) * 100;
                document.getElementById('cyber-phase3').value = (config.cyberboss.phaseThresholds.phase3 ?? 0.50) * 100;
                document.getElementById('cyber-phase4').value = (config.cyberboss.phaseThresholds.phase4 ?? 0.25) * 100;
            }
        }

        if (config.zeroDay) {
            document.getElementById('zeroday-hp').value = config.zeroDay.baseHP ?? 9999;
            document.getElementById('zeroday-speed').value = config.zeroDay.speed ?? 30;
            document.getElementById('zeroday-drain').value = config.zeroDay.efficiencyDrainRate ?? 2.0;
            document.getElementById('zeroday-min-waves').value = config.zeroDay.minWavesBeforeSpawn ?? 3;
            document.getElementById('zeroday-hash').value = config.zeroDay.defeatHashBonus ?? 525;
            document.getElementById('zeroday-restore').value = config.zeroDay.defeatEfficiencyRestore ?? 30;
        }

        if (config.components) {
            document.getElementById('comp-max-level').value = config.components.maxLevel ?? 10;
            if (config.components.baseCosts) {
                ['psu','ram','gpu','cache','storage','expansion','network','io','cpu'].forEach(id => {
                    document.getElementById('comp-cost-' + id).value = config.components.baseCosts[id] ?? 500;
                });
            }
        }

        if (config.efficiency) {
            document.getElementById('eff-leak-interval').value = config.efficiency.leakDecayInterval ?? 5.0;
            document.getElementById('eff-warning').value = config.efficiency.warningThreshold ?? 25;
            document.getElementById('freeze-cost-pct').value = config.efficiency.freezeRecoveryCostPct ?? 10;
            document.getElementById('freeze-target-eff').value = config.efficiency.freezeRecoveryTarget ?? 50;
            document.getElementById('ram-base-regen').value = config.efficiency.ramBaseRegen ?? 1.0;
            document.getElementById('ram-regen-per-level').value = config.efficiency.ramRegenPerLevel ?? 0.111;
        }

        if (config.sectorUnlock && config.sectorUnlock.hashCosts) {
            config.sectorUnlock.hashCosts.forEach((cost, i) => {
                document.getElementById('sector-cost-' + i).value = cost;
            });
        }

        // Update all charts
        updateProtocolChart();
        updateHashChart();
        updatePowerChart();
        updateThreatChart();
        updateBossChart();
        updateComponentChart();
        updateProtocolCompare();
        updateEfficiencyChart();
        updateSectorChart();

        alert('Configuration imported successfully!');
    } catch (e) {
        alert('Error parsing JSON: ' + e.message);
    }
}

function generateSwiftCode() {
    const swift = `// Generated by Balance Simulator
// Copy relevant sections to BalanceConfig.swift

struct ProtocolScaling {
    static let damageMultiplierPerLevel: CGFloat = ${document.getElementById('proto-dmg-mult').value}
    static let rangePerLevel: CGFloat = ${document.getElementById('proto-range-mult').value}
    static let fireRatePerLevel: CGFloat = ${document.getElementById('proto-fire-mult').value}
    static let maxLevel: Int = ${document.getElementById('proto-max-level').value}
}

struct HashEconomy {
    static let baseHashPerSecond: CGFloat = ${document.getElementById('hash-base').value}
    static let cpuLevelScaling: CGFloat = ${document.getElementById('hash-cpu-mult').value}
    static let baseStorageCapacity: Int = ${document.getElementById('storage-base').value}
    static let storagePerUpgrade: Int = ${document.getElementById('storage-per-level').value}
    static let offlineEarningsRate: CGFloat = ${parseFloat(document.getElementById('offline-rate').value) / 100}
    static let maxOfflineHours: CGFloat = ${document.getElementById('offline-max-hours').value}
}

struct Overclock {
    static let duration: TimeInterval = ${document.getElementById('overclock-duration').value}
    static let hashMultiplier: CGFloat = ${document.getElementById('overclock-mult').value}
    static let powerDemandMultiplier: CGFloat = ${document.getElementById('overclock-power-mult').value}
}

struct PowerGrid {
    static let basePowerBudget: Int = ${document.getElementById('power-base').value}
    static let powerPerCPULevel: Int = ${document.getElementById('power-per-level').value}
    // Tower power is defined per-protocol in Protocol.swift
}

struct ThreatLevel {
    static let maxThreatLevel: CGFloat = ${document.getElementById('threat-max').value}
    static let onlineThreatGrowthRate: CGFloat = ${document.getElementById('threat-online-rate').value}
    static let offlineThreatGrowthRate: CGFloat = ${document.getElementById('threat-offline-rate').value}
    static let healthScaling: CGFloat = ${document.getElementById('threat-hp-scale').value}
    static let speedScaling: CGFloat = ${document.getElementById('threat-speed-scale').value}
    static let damageScaling: CGFloat = ${document.getElementById('threat-dmg-scale').value}
    static let fastEnemyThreshold: CGFloat = ${document.getElementById('unlock-fast').value}
    static let swarmEnemyThreshold: CGFloat = ${document.getElementById('unlock-swarm').value}
    static let tankEnemyThreshold: CGFloat = ${document.getElementById('unlock-tank').value}
    static let eliteEnemyThreshold: CGFloat = ${document.getElementById('unlock-elite').value}
    static let bossEnemyThreshold: CGFloat = ${document.getElementById('unlock-boss').value}
}

struct Cyberboss {
    static let baseHealth: CGFloat = ${document.getElementById('cyber-hp').value}
    static let healthScalingPerWave: CGFloat = ${document.getElementById('cyber-hp-scale').value}
    static let laserDamage: CGFloat = ${document.getElementById('cyber-laser-dmg').value}
    static let laserWarningDuration: TimeInterval = ${document.getElementById('cyber-laser-warn').value}
    static let puddleDamagePerSecond: CGFloat = ${document.getElementById('cyber-puddle-dmg').value}
    static let puddleDuration: TimeInterval = ${document.getElementById('cyber-puddle-dur').value}
    static let spawnWaveSize: Int = ${document.getElementById('cyber-spawn-count').value}
    static let spawnInterval: TimeInterval = ${document.getElementById('cyber-spawn-interval').value}
    static let phase2Threshold: CGFloat = ${parseInt(document.getElementById('cyber-phase2').value) / 100}
    static let phase3Threshold: CGFloat = ${parseInt(document.getElementById('cyber-phase3').value) / 100}
    static let phase4Threshold: CGFloat = ${parseInt(document.getElementById('cyber-phase4').value) / 100}
}

struct ZeroDay {
    static let baseHealth: CGFloat = ${document.getElementById('zeroday-hp').value}
    static let speed: CGFloat = ${document.getElementById('zeroday-speed').value}
    static let efficiencyDrainRate: CGFloat = ${document.getElementById('zeroday-drain').value}
    static let minWavesBeforeSpawn: Int = ${document.getElementById('zeroday-min-waves').value}
    static let defeatHashBonus: Int = ${document.getElementById('zeroday-hash').value}
    static let defeatEfficiencyRestore: Int = ${document.getElementById('zeroday-restore').value}
}`;

    document.getElementById('swift-export').value = swift;
}

function copyToClipboard(elementId) {
    const textarea = document.getElementById(elementId);
    textarea.select();
    document.execCommand('copy');
    alert('Copied to clipboard!');
}

// Utility functions
function formatTime(seconds) {
    if (seconds < 60) return Math.floor(seconds) + 's';
    if (seconds < 3600) return (seconds / 60).toFixed(1) + 'm';
    return (seconds / 3600).toFixed(1) + 'h';
}
