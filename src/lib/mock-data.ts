export const dashboardStats = [
  { label: 'Open Orders', value: '18', note: '6 need production' },
  { label: 'Finished Goods Available', value: '312', note: 'Across 3 product lines' },
  { label: 'Raw Material Alerts', value: '4', note: 'Below minimum stock' },
  { label: 'Open Tasks', value: '27', note: '5 overdue' },
];

export const products = [
  {
    code: 'YP-MOP-001',
    name: 'Youngpro Mop Handle Set',
    price: 'Rp45.000',
    stock: 25,
    reserved: 20,
    available: 5,
    bom: ['Plastic Granule PP', 'Aluminum Pole', 'Packaging Box', 'Sticker Label'],
  },
  {
    code: 'YP-MFC-001',
    name: 'Youngpro Microfiber Cloth Pack',
    price: 'Rp25.000',
    stock: 90,
    reserved: 12,
    available: 78,
    bom: ['Microfiber Roll', 'Packaging Box', 'Sticker Label'],
  },
  {
    code: 'YP-SQG-001',
    name: 'Youngpro Floor Squeegee 45cm',
    price: 'Rp38.000',
    stock: 10,
    reserved: 8,
    available: 2,
    bom: ['Plastic Granule PP', 'Rubber Strip 45cm', 'Packaging Box'],
  },
];

export const salesOrders = [
  {
    no: 'SO-202606-00031',
    customer: 'PT Contoh Distributor Bersih',
    item: 'Youngpro Mop Handle Set',
    qty: 60,
    reserved: 25,
    shortage: 35,
    status: 'Needs Production',
  },
  {
    no: 'SO-202606-00032',
    customer: 'CV Bersih Mandiri',
    item: 'Microfiber Cloth Pack',
    qty: 40,
    reserved: 40,
    shortage: 0,
    status: 'Reserved',
  },
  {
    no: 'SO-202606-00033',
    customer: 'Toko Hygiene Jaya',
    item: 'Floor Squeegee 45cm',
    qty: 20,
    reserved: 10,
    shortage: 10,
    status: 'Needs Production',
  },
];

export const rawMaterials = [
  { code: 'RM-PP-001', name: 'Plastic Granule PP', unit: 'KG', onHand: 250, reserved: 18.5, available: 231.5, min: 50 },
  { code: 'RM-MF-001', name: 'Microfiber Roll', unit: 'ROLL', onHand: 80, reserved: 2, available: 78, min: 20 },
  { code: 'RM-AL-001', name: 'Aluminum Pole', unit: 'PCS', onHand: 300, reserved: 35, available: 265, min: 100 },
  { code: 'RM-RB-001', name: 'Rubber Strip 45cm', unit: 'PCS', onHand: 200, reserved: 10, available: 190, min: 150 },
];

export const productionBatches = [
  {
    no: 'PB-202606-00012',
    product: 'Youngpro Mop Handle Set',
    planned: 35,
    output: 0,
    order: 'SO-202606-00031',
    progress: 62,
    status: 'In Progress',
  },
  {
    no: 'PB-202606-00013',
    product: 'Youngpro Floor Squeegee 45cm',
    planned: 10,
    output: 0,
    order: 'SO-202606-00033',
    progress: 25,
    status: 'Materials Reserved',
  },
];

export const tasks = [
  { no: 'TASK-202606-00044', title: 'Prepare raw materials for mop batch', assignee: 'Staff Produksi A', status: 'In Progress', priority: 'High', proof: 'Waiting' },
  { no: 'TASK-202606-00045', title: 'Photo proof after material count', assignee: 'Staff Gudang B', status: 'Submitted', priority: 'Normal', proof: 'Review' },
  { no: 'TASK-202606-00046', title: 'Supervisor check final output', assignee: 'Supervisor Produksi', status: 'Open', priority: 'High', proof: 'Not Required Yet' },
];

export const stockMovements = [
  { time: '09:12', type: 'Opening Balance', item: 'Plastic Granule PP', qty: '+250 KG', ref: 'Seed' },
  { time: '10:04', type: 'Reservation', item: 'Mop Handle Set', qty: '25 PCS locked', ref: 'SO-202606-00031' },
  { time: '11:20', type: 'Production Plan', item: 'Mop Handle Set', qty: '35 PCS shortage', ref: 'PB-202606-00012' },
  { time: '14:35', type: 'Proof Submitted', item: 'Material Count Photo', qty: '1 file', ref: 'TASK-202606-00045' },
];
