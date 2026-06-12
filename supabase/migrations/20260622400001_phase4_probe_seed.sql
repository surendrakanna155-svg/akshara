-- Phase 4 probe seeds (tenant isolation — School A / School B)

INSERT INTO inv_catalog_items (
  id, organization_id, school_id, category, name, sku_code, unit_price, stock_on_hand
) VALUES
  (
    'b1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'books', 'Mathematics Textbook Grade 8', 'BK-MATH-8', 45000, 120
  ),
  (
    'b1000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'uniforms', 'School Uniform Set', 'UNI-SET', 120000, 80
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO inv_student_distributions (
  id, organization_id, school_id, student_id, catalog_item_id, quantity, status
) VALUES
  (
    'b2000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    1, 'distributed'
  )
ON CONFLICT (id) DO NOTHING;
