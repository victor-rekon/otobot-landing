import {
  dashboardStats,
  products,
  productionBatches,
  rawMaterials,
  salesOrders,
  stockMovements,
  tasks,
} from '@/src/lib/mock-data';

const modules = [
  'Dashboard',
  'Product Catalog',
  'Sales Order',
  'Bahan Baku',
  'Barang Jadi',
  'Production Batch',
  'Task Delegation',
  'Proof of Work',
  'Reports',
];

function StatusBadge({ status }: { status: string }) {
  const n = status.toLowerCase();
  const tone = n.includes('need') || n.includes('short') ? 'danger'
    : n.includes('reserved') || n.includes('approved') ? 'success'
    : n.includes('progress') || n.includes('review') || n.includes('submitted') ? 'warning'
    : 'neutral';
  return <span className={`badge ${tone}`}>{status}</span>;
}

function SectionHeader({ eyebrow, title, description }: { eyebrow: string; title: string; description: string }) {
  return (
    <div className="section-header">
      <span>{eyebrow}</span>
      <h2>{title}</h2>
      <p>{description}</p>
    </div>
  );
}

/* ── Inline SVG bar charts — no external library ── */
function FinishedGoodsChart() {
  return (
    <div className="chart-card">
      <p className="chart-eyebrow">Finished Goods</p>
      <h3 className="chart-title">Stok Tersedia vs Total</h3>
      <div className="bar-chart">
        {products.map(p => {
          const pct = Math.round((p.available / p.stock) * 100);
          const color = pct < 30 ? 'var(--red)' : pct < 60 ? 'var(--amber)' : 'var(--green)';
          const label = p.name.replace('Youngpro ', '');
          return (
            <div className="bar-row" key={p.code}>
              <div className="bar-label" title={label}>{label}</div>
              <div className="bar-track">
                <div className="bar-fill" style={{ width: `${pct}%`, background: color }} />
              </div>
              <div className="bar-stat">{p.available}<span>/{p.stock}</span></div>
            </div>
          );
        })}
        <div className="chart-legend">
          <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--green)' }} />Stok aman (&gt;60%)</div>
          <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--amber)' }} />Perlu perhatian (30–60%)</div>
          <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--red)' }} />Kritis (&lt;30%)</div>
        </div>
      </div>
    </div>
  );
}

function RawMaterialChart() {
  const maxVal = Math.max(...rawMaterials.map(m => m.onHand));
  return (
    <div className="chart-card">
      <p className="chart-eyebrow">Bahan Baku</p>
      <h3 className="chart-title">Tersedia vs Minimum</h3>
      <div className="bar-chart">
        {rawMaterials.map(m => {
          const pct = Math.round((m.available / maxVal) * 100);
          const minPct = Math.round((m.min / maxVal) * 100);
          const safe = m.available >= m.min * 2;
          const warn = m.available >= m.min && m.available < m.min * 2;
          const color = safe ? 'var(--blue)' : warn ? 'var(--amber)' : 'var(--red)';
          const short = m.name.length > 16 ? m.name.slice(0, 14) + '…' : m.name;
          return (
            <div className="bar-row" key={m.code}>
              <div className="bar-label" title={m.name}>{short}</div>
              <div className="bar-track">
                <div className="bar-min-line" style={{ left: `${minPct}%` }} />
                <div className="bar-fill" style={{ width: `${pct}%`, background: color }} />
              </div>
              <div className="bar-stat">{m.available}<span> {m.unit}</span></div>
            </div>
          );
        })}
        <div className="chart-legend">
          <div className="legend-item"><span className="legend-dot" style={{ background: 'rgba(255,255,255,.3)', border: '1px solid rgba(255,255,255,.3)' }} />Garis putih = minimum stok</div>
        </div>
      </div>
    </div>
  );
}

function ProductionProgressChart() {
  const orderStatus = [
    { label: 'Needs Production', count: salesOrders.filter(o => o.status === 'Needs Production').length, color: 'var(--red)' },
    { label: 'Reserved / Ready', count: salesOrders.filter(o => o.status === 'Reserved').length, color: 'var(--green)' },
  ];
  const totalOrders = salesOrders.length;

  return (
    <div className="chart-card">
      <p className="chart-eyebrow">Production & Orders</p>
      <h3 className="chart-title">Progress Batch & Status SO</h3>
      <div className="bar-chart">
        {productionBatches.map(b => {
          const label = b.product.replace('Youngpro ', '');
          const color = b.progress >= 60 ? 'var(--blue)' : b.progress >= 30 ? 'var(--amber)' : 'var(--red)';
          return (
            <div className="bar-row" key={b.no}>
              <div className="bar-label" title={label}>{label}</div>
              <div className="bar-track">
                <div className="bar-fill" style={{ width: `${b.progress}%`, background: color }} />
              </div>
              <div className="bar-stat">{b.progress}<span>%</span></div>
            </div>
          );
        })}
        {/* Mini SO status breakdown */}
        <div style={{ marginTop: '8px', paddingTop: '14px', borderTop: '1px solid var(--line)' }}>
          <p style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '.12em', textTransform: 'uppercase', color: 'var(--t3)', marginBottom: '10px' }}>Sales Order Status</p>
          {orderStatus.map(s => (
            <div className="bar-row" key={s.label} style={{ marginBottom: '8px' }}>
              <div className="bar-label">{s.label}</div>
              <div className="bar-track">
                <div className="bar-fill" style={{ width: `${(s.count / totalOrders) * 100}%`, background: s.color }} />
              </div>
              <div className="bar-stat">{s.count}<span>/{totalOrders}</span></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-card">
          <div className="brand-mark">Y</div>
          <div>
            <strong>Youngpro</strong>
            <span>Ops System</span>
          </div>
        </div>

        <nav className="nav-list" aria-label="Main modules">
          {modules.map((module, index) => (
            <a key={module} href={`#${module.toLowerCase().replaceAll(' ', '-')}`} className={index === 0 ? 'active' : ''}>
              <span>{String(index + 1).padStart(2, '0')}</span>
              {module}
            </a>
          ))}
        </nav>

        <div className="sidebar-note">
          <strong>Scope Guard</strong>
          <p>No marketplace, no accounting, no payroll. Workflow-to-system control only.</p>
        </div>
      </aside>

      <section className="content">

        {/* Hero */}
        <header className="hero" id="dashboard">
          <div>
            <p className="eyebrow">SistemBeres Internal Demo</p>
            <h1>Inventory, Production,<br />Task &amp; Proof Control.</h1>
            <p className="hero-copy">
              Product catalog → sales order → stock check → production batch → staff task → proof approval → finished goods → fulfillment.
            </p>
          </div>
          <div className="hero-panel">
            <span>Current workflow state</span>
            <strong>6 orders need production</strong>
            <p>Stock reservation is separated from physical deduction to keep reporting honest.</p>
          </div>
        </header>

        {/* Stats */}
        <section className="stats-grid">
          {dashboardStats.map((stat) => (
            <article className="stat-card" key={stat.label}>
              <span>{stat.label}</span>
              <strong>{stat.value}</strong>
              <p>{stat.note}</p>
            </article>
          ))}
        </section>

        {/* Charts */}
        <section className="charts-grid" id="charts">
          <FinishedGoodsChart />
          <RawMaterialChart />
          <ProductionProgressChart />
        </section>

        {/* Workflow */}
        <section className="workflow-strip">
          {['Order Draft', 'Reserve Stock', 'Create Batch', 'Assign Task', 'Approve Proof', 'Fulfill Order'].map((step) => (
            <div key={step}>{step}</div>
          ))}
        </section>

        {/* Product Catalog */}
        <section className="module-grid" id="product-catalog">
          <SectionHeader
            eyebrow="Product Catalog"
            title="Sellable products with BOM control"
            description="Each sellable product links to finished goods stock and raw material consumption rules."
          />
          <div className="cards three">
            {products.map((product) => (
              <article className="product-card" key={product.code}>
                <div className="card-topline">
                  <span>{product.code}</span>
                  <strong>{product.price}</strong>
                </div>
                <h3>{product.name}</h3>
                <div className="stock-row">
                  <span>On hand: {product.stock}</span>
                  <span>Reserved: {product.reserved}</span>
                  <span>Available: {product.available}</span>
                </div>
                <div className="bom-list">
                  {product.bom.map((item) => <span key={item}>{item}</span>)}
                </div>
              </article>
            ))}
          </div>
        </section>

        {/* Sales Order */}
        <section className="module-grid" id="sales-order">
          <SectionHeader
            eyebrow="Sales Order"
            title="Order stock check and automatic shortage handling"
            description="Orders reserve finished stock first. Shortage becomes a production batch instead of corrupting stock reports."
          />
          <div className="table-card">
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Customer</th>
                  <th>Item</th>
                  <th>Qty</th>
                  <th>Reserved</th>
                  <th>Shortage</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {salesOrders.map((order) => (
                  <tr key={order.no}>
                    <td>{order.no}</td>
                    <td>{order.customer}</td>
                    <td>{order.item}</td>
                    <td>{order.qty}</td>
                    <td>{order.reserved}</td>
                    <td>{order.shortage}</td>
                    <td><StatusBadge status={order.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        {/* Bahan Baku + Barang Jadi */}
        <section className="split-grid" id="bahan-baku">
          <div>
            <SectionHeader
              eyebrow="Bahan Baku"
              title="Raw material availability"
              description="Raw materials are reserved for production before they are deducted."
            />
            <div className="table-card compact">
              <table>
                <thead>
                  <tr><th>Code</th><th>Item</th><th>Available</th><th>Min</th></tr>
                </thead>
                <tbody>
                  {rawMaterials.map((item) => (
                    <tr key={item.code}>
                      <td>{item.code}</td>
                      <td>{item.name}</td>
                      <td>{item.available} {item.unit}</td>
                      <td>{item.min}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div id="barang-jadi">
            <SectionHeader
              eyebrow="Barang Jadi"
              title="Finished goods position"
              description="Finished stock is deducted only when sales order is fulfilled or shipped."
            />
            <div className="cards one">
              {products.map((product) => (
                <article className="mini-stock" key={product.code}>
                  <strong>{product.name}</strong>
                  <div className="progress-track">
                    <div style={{ width: `${Math.min(product.available * 2, 100)}%` }} />
                  </div>
                  <span>{product.available} available / {product.stock} on hand</span>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Production Batch */}
        <section className="module-grid" id="production-batch">
          <SectionHeader
            eyebrow="Production Batch"
            title="Production batches linked to sales shortages"
            description="Short stock does not disappear. It becomes a visible batch with material plans and task control."
          />
          <div className="cards two">
            {productionBatches.map((batch) => (
              <article className="batch-card" key={batch.no}>
                <div className="card-topline">
                  <span>{batch.no}</span>
                  <StatusBadge status={batch.status} />
                </div>
                <h3>{batch.product}</h3>
                <p>Linked order: {batch.order}</p>
                <div className="progress-track large">
                  <div style={{ width: `${batch.progress}%` }} />
                </div>
                <div className="stock-row">
                  <span>Planned: {batch.planned}</span>
                  <span>Output: {batch.output}</span>
                  <span>{batch.progress}% complete</span>
                </div>
              </article>
            ))}
          </div>
        </section>

        {/* Task Delegation + Proof */}
        <section className="split-grid" id="task-delegation">
          <div>
            <SectionHeader
              eyebrow="Task Delegation"
              title="Supervisor assigns work, staff submits progress"
              description="Production is not just a batch number. It needs task ownership and evidence."
            />
            <div className="task-list">
              {tasks.map((task) => (
                <article className="task-card" key={task.no}>
                  <div>
                    <span>{task.no}</span>
                    <h3>{task.title}</h3>
                    <p>{task.assignee}</p>
                  </div>
                  <div>
                    <StatusBadge status={task.status} />
                    <small>{task.priority}</small>
                  </div>
                </article>
              ))}
            </div>
          </div>

          <div id="proof-of-work">
            <SectionHeader
              eyebrow="Proof of Work"
              title="Supervisor review gate"
              description="Production cannot be confirmed while required proof is still waiting or rejected."
            />
            <div className="proof-card">
              <div className="proof-preview">PHOTO / FILE</div>
              <h3>Material count proof</h3>
              <p>Submitted by Staff Gudang B. Waiting for supervisor approval.</p>
              <div className="button-row" style={{ marginTop: '16px' }}>
                <button>Approve Proof</button>
                <button className="secondary">Request Revision</button>
              </div>
            </div>
          </div>
        </section>

        {/* Reports */}
        <section className="module-grid" id="reports">
          <SectionHeader
            eyebrow="Reports"
            title="Stock movement and owner visibility"
            description="Every operational action leaves a trace: reservation, batch, proof, output, and fulfillment."
          />
          <div className="table-card">
            <table>
              <thead>
                <tr><th>Time</th><th>Type</th><th>Item</th><th>Qty</th><th>Reference</th></tr>
              </thead>
              <tbody>
                {stockMovements.map((movement) => (
                  <tr key={`${movement.time}-${movement.ref}`}>
                    <td>{movement.time}</td>
                    <td>{movement.type}</td>
                    <td>{movement.item}</td>
                    <td>{movement.qty}</td>
                    <td>{movement.ref}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

      </section>
    </main>
  );
}
