document.addEventListener('DOMContentLoaded', () => {
    const plansGrid = document.getElementById('plans-grid');
    const loader = document.getElementById('loader');
    const filterBtns = document.querySelectorAll('.filter-btn');
    const modal = document.getElementById('plan-modal');
    const modalBody = document.getElementById('modal-body');
    const closeBtn = document.querySelector('.close-btn');

    let allPlansData = [];

    // Format numbers
    const formatWon = (num) => new Intl.NumberFormat('ko-KR').format(num) + '원';

    // Initial Fetch
    fetchPlans('all');

    // Event Listeners for Filters
    filterBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            filterBtns.forEach(b => b.classList.remove('active'));
            e.target.classList.add('active');
            const query = e.target.dataset.query;
            fetchPlans(query);
        });
    });

    // Close Modal
    closeBtn.addEventListener('click', () => modal.classList.add('hidden'));
    window.addEventListener('click', (e) => {
        if (e.target === modal) modal.classList.add('hidden');
    });

    async function fetchPlans(type) {
        plansGrid.innerHTML = '';
        loader.classList.remove('hidden');

        try {
            let res;
            if (type === 'all') {
                res = await fetch('/api/plans');
            } else if (type === 'youth') {
                res = await fetch('/api/query/youth');
            } else if (type === 'family') {
                res = await fetch('/api/query/family');
            }
            
            const json = await res.json();
            if (json.status === 'success') {
                allPlansData = json.data;
                renderPlans(json.data, type);
            }
        } catch (err) {
            console.error(err);
            plansGrid.innerHTML = '<p style="color: red; grid-column: 1/-1; text-align: center;">데이터를 불러오는 데 실패했습니다. 서버 연동 로그를 확인해 주세요.</p>';
        } finally {
            loader.classList.add('hidden');
        }
    }

    function renderPlans(data, type) {
        if (data.length === 0) {
            plansGrid.innerHTML = '<p style="grid-column: 1/-1; text-align: center;">해당 조건에 맞는 요금제가 없습니다.</p>';
            return;
        }

        data.forEach(item => {
            const card = document.createElement('div');
            card.className = 'plan-card glass-panel';
            
            // Dynamic Content based on query type
            if (type === 'all') {
                card.innerHTML = `
                    <div class="graph-badge">Neo4j Graph</div>
                    <div class="plan-category">${item.category}</div>
                    <div class="plan-name">${item.name}</div>
                    <div class="plan-price">${formatWon(item.price)}<span>/월</span></div>
                    <ul class="features-list">
                        <li>데이터: ${item.data}</li>
                        <li>공유 데이터: ${item.shared_data || '없음'}</li>
                        ${item.ott_services?.length ? `<li>OTT 혜택 제공</li>` : ''}
                    </ul>
                    <div class="tags">
                        ${(item.benefits || []).slice(0,2).map(b => `<span class="tag">${b}</span>`).join('')}
                    </div>
                `;
                
                // Add click event for full API data inspection
                card.addEventListener('click', () => showPlanDetails(item));
            } 
            else if (type === 'youth') {
                card.innerHTML = `
                    <div class="graph-badge">Query: Youth</div>
                    <div class="plan-category">만 34세 이하 할인</div>
                    <div class="plan-name">${item.name}</div>
                    <div class="plan-price" style="color: #60a5fa; margin-bottom: 0.5rem;">${formatWon(item.discounted_price)}<span>/월 (할인 적용)</span></div>
                    <p style="text-decoration: line-through; color: #6b7280; margin-bottom: 1.5rem;">기존 ${formatWon(item.original_price)}</p>
                    <ul class="features-list">
                        <li>${item.description}</li>
                        <li>할인율: ${item.discount_rate * 100}% 추가 할인</li>
                    </ul>
                `;
            }
            else if (type === 'family') {
                card.innerHTML = `
                    <div class="graph-badge">Query: Family</div>
                    <div class="plan-category">가족 결합 혜택 플랜</div>
                    <div class="plan-name">${item.name}</div>
                    <ul class="features-list" style="margin-top: 1.5rem;">
                        <li><strong>조건:</strong> ${item.condition}</li>
                        <li><strong>혜택:</strong> ${item.benefit}</li>
                    </ul>
                `;
            }

            plansGrid.appendChild(card);
        });
    }

    function showPlanDetails(plan) {
        modalBody.innerHTML = `
            <h2>${plan.name}</h2>
            <p style="color: var(--text-muted)">${plan.category}</p>
            
            <div class="modal-section">
                <h3>요금 및 기본 제공</h3>
                <ul class="features-list">
                    <li>월 정액: ${formatWon(plan.price)}</li>
                    <li>데이터: ${plan.data}</li>
                    <li>공유 데이터: ${plan.shared_data || '제공 안함'}</li>
                </ul>
            </div>

            ${plan.ott_services && plan.ott_services.length > 0 ? `
            <div class="modal-section">
                <h3>OTT 혜택</h3>
                <div class="tags">
                    ${plan.ott_services.map(s => `<span class="tag" style="background: rgba(230,0,126,0.2)">${s}</span>`).join('')}
                </div>
            </div>` : ''}

            ${plan.benefits && plan.benefits.length > 0 ? `
            <div class="modal-section">
                <h3>추가 혜택 (-[:INCLUDES]->)</h3>
                <ul class="features-list">
                    ${plan.benefits.map(b => `<li>${b}</li>`).join('')}
                </ul>
            </div>` : ''}

            ${plan.conditions && plan.conditions.length > 0 ? `
            <div class="modal-section">
                <h3>가입 조건 (-[:REQUIRES]->)</h3>
                <ul class="features-list">
                    ${plan.conditions.map(c => `<li>${c}</li>`).join('')}
                </ul>
            </div>` : ''}
        `;
        modal.classList.remove('hidden');
    }
});
