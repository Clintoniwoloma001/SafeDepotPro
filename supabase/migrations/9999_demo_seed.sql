insert into public.depots (id, code, name, city, region, latitude, longitude) values
  ('11111111-1111-1111-1111-111111111111', 'KAM', 'Kampala Yard', 'Kampala', 'Central', 0.3136, 32.5811),
  ('22222222-2222-2222-2222-222222222222', 'EBB', 'Entebbe Depot', 'Entebbe', 'Central', 0.047, 32.4561),
  ('33333333-3333-3333-3333-333333333333', 'MWE', 'Mbarara Depot', 'Mbarara', 'Western', -0.6072, 30.6545)
on conflict (id) do nothing;

insert into public.depot_zones (depot_id, name) values
  ('11111111-1111-1111-1111-111111111111', 'Fueling Bay'),
  ('11111111-1111-1111-1111-111111111111', 'Workshop'),
  ('11111111-1111-1111-1111-111111111111', 'Warehouse'),
  ('22222222-2222-2222-2222-222222222222', 'Ramp')
on conflict do nothing;

insert into public.routine_tasks (title, task_type, category, all_depots, frequency, start_date, requires_photo_on_completion, sequence_order) values
  ('Daily Depot Housekeeping Walkthrough', 'MANUAL', 'Housekeeping', true, 'DAILY', current_date, true, 1),
  ('Weekly Fire Extinguisher Check', 'COUNT', 'Fire Safety', true, 'WEEKLY', current_date, false, 2),
  ('Monthly Ladder and Scaffold Inspection', 'FORM', 'Equipment', true, 'MONTHLY', current_date, true, 3),
  ('Quarterly Emergency Drill', 'AI_VERIFIED', 'Emergency', true, 'QUARTERLY', current_date, true, 4),
  ('Annual Risk Assessment Review', 'FORM', 'Risk', true, 'ANNUAL', current_date, false, 5)
on conflict do nothing;

insert into public.checklist_templates (name, type, description, is_factory, sections) values
  ('Wheel Loader Pre-Use Inspection', 'TRUCK', 'Factory truck/equipment checklist', true, jsonb_build_array(
    jsonb_build_object('id', 's1', 'title', 'Exterior', 'questions', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid()::text, 'text', 'Bodywork undamaged and clean', 'severity', 2, 'requires_photo', false),
      jsonb_build_object('id', gen_random_uuid()::text, 'text', 'Tyres adequate tread, no damage', 'severity', 2, 'requires_photo', true)
    ))
  )),
  ('General Depot Safety Tour', 'HSE', 'Factory HSE checklist', true, jsonb_build_array(
    jsonb_build_object('id', 's1', 'title', 'Walkthrough', 'questions', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid()::text, 'text', 'Housekeeping standard maintained', 'severity', 2, 'requires_photo', false),
      jsonb_build_object('id', gen_random_uuid()::text, 'text', 'Fire extinguishers accessible and sealed', 'severity', 4, 'requires_photo', false)
    ))
  ))
on conflict do nothing;