# Action Coverage Matrix (Post M13)

**Generated:** 2026-06-15 20:06 UTC

## Summary

| Category | Discovered | Keyed (QaTestKeys) | Patrol |
|----------|----------:|-------------------:|-------:|
| Buttons / CTAs | 111 | 170 | see baseline |
| Filters | 59 | — | partial |
| Exports | 91 | 0 | partial |
| AI actions | 546 | 1 | partial |

---

## 1. Buttons & quick actions

| Action | Screen | Module | Widget | Keyed | Patrol |
|--------|--------|--------|--------|:-----:|:------:|
| ${entry.sectionId} · v${entry.version} | `timetable_hub_screen` | Other | dropdown | No | No |
| <filled_x1> | `admissions_applications_screen` | Admissions | filled | No | No |
| Approve | `admissions_approval_review_panel` | Admissions | filled | Yes | Partial |
| <icon_x1> | `admissions_followups_table` | Admissions | icon | No | No |
| Approve | `admissions_document_checklist` | Admissions | filled | Yes | Partial |
| Verify | `admissions_documents_table` | Admissions | text | Yes | Partial |
| Send to Finance | `admissions_fee_handoff_panel` | Admissions | filled | No | No |
| <filled_x1> | `admissions_leads_screen` | Admissions | filled | No | No |
| <filled_x1> | `admissions_settings_screen` | Admissions | filled | No | No |
| <icon_x1> | `alumni_reports_screen` | Alumni | icon | No | No |
| <icon_x1> | `alumni_settings_screen` | Alumni | icon | No | No |
| <filled_x2> | `login_screen` | Auth | filled | No | No |
| <text_x1> | `login_screen` | Auth | text | No | No |
| <filled_x1> | `control_center_crm_screen` | Control Center | filled | No | No |
| AI | `control_center_providers_screen` | Control Center | dropdown | Yes | Partial |
| WhatsApp | `control_center_providers_screen` | Control Center | dropdown | No | No |
| SMS | `control_center_providers_screen` | Control Center | dropdown | No | No |
| OpenAI | `control_center_providers_screen` | Control Center | dropdown | No | No |
| Claude | `control_center_providers_screen` | Control Center | dropdown | No | No |
| Gemini | `control_center_providers_screen` | Control Center | dropdown | No | No |
| MSG91 | `control_center_providers_screen` | Control Center | dropdown | No | No |
| Gupshup | `control_center_providers_screen` | Control Center | dropdown | No | No |
| <icon_x1> | `control_center_roles_screen` | Control Center | icon | No | No |
| <filled_x1> | `control_center_schools_screen` | Control Center | filled | No | No |
| <icon_x1> | `control_center_settings_screen` | Control Center | icon | No | No |
| <filled_x1> | `director_shared_widgets` | Director | filled | No | No |
| School | `dynamic_widget_layout_editor_screen` | Dynamic Widgets | dropdown | Yes | Partial |
| Salon | `dynamic_widget_layout_editor_screen` | Dynamic Widgets | dropdown | Yes | Partial |
| Hospital | `dynamic_widget_layout_editor_screen` | Dynamic Widgets | dropdown | No | No |
| Restaurant | `dynamic_widget_layout_editor_screen` | Dynamic Widgets | dropdown | Yes | Partial |
| <filled_x1> | `dynamic_widget_registry_screen` | Dynamic Widgets | filled | No | No |
| English | `parent_insights_screen` | Parent | menu | No | No |
| Hindi | `parent_insights_screen` | Parent | menu | No | No |
| Telugu | `parent_insights_screen` | Parent | menu | No | No |
| Generate daily | `parent_insights_screen` | Parent | menu | No | No |
| Generate weekly | `parent_insights_screen` | Parent | menu | No | No |
| Generate monthly | `parent_insights_screen` | Parent | menu | No | No |
| Exam preparation | `parent_insights_screen` | Parent | menu | No | No |
| All classes | `teacher_assistant_screen` | SIS | menu | No | No |
| Grade 8 | `teacher_assistant_screen` | SIS | menu | No | No |
| Grade 7 | `teacher_assistant_screen` | SIS | menu | No | No |
| <filled_x1> | `finance_collections_screen` | Finance | filled | No | No |
| <filled_x1> | `finance_discounts_screen` | Finance | filled | No | No |
| <filled_x1> | `finance_fee_assignment_screen` | Finance | filled | No | No |
| <filled_x1> | `finance_invoice_management_section` | Finance | filled | No | No |
| Cash | `finance_offline_payments_screen` | Finance | dropdown | No | No |
| Cheque | `finance_offline_payments_screen` | Finance | dropdown | No | No |
| Demand Draft | `finance_offline_payments_screen` | Finance | dropdown | No | No |
| <icon_x1> | `finance_settings_screen` | Finance | icon | No | No |
| unit_test | `homework_intelligence_screen` | Intelligence | dropdown | No | No |
| monthly_test | `homework_intelligence_screen` | Intelligence | dropdown | No | No |
| <icon_x1> | `hostel_reports_screen` | Hostel | icon | No | No |
| <filled_x1> | `hr_payroll_screen` | HR | filled | No | No |
| <icon_x1> | `hr_settings_screen` | HR | icon | No | No |
| Apply | `exam_intelligence_screen` | Intelligence | filled | Yes | Partial |
| Generate structured summary | `teacher_effectiveness_screen` | Intelligence | filled | No | No |
| <filled_x1> | `inventory_lifecycle_screen` | Inventory | filled | No | No |
| <icon_x1> | `inventory_reports_screen` | Inventory | icon | No | No |
| <filled_x1> | `library_catalog_screen` | Library | filled | No | No |
| Good | `library_workflow_actions` | Library | dropdown | No | No |
| Fair | `library_workflow_actions` | Library | dropdown | No | No |
| Damaged | `library_workflow_actions` | Library | dropdown | No | No |
| <icon_x1> | `library_reports_screen` | Library | icon | No | No |
| <filled_x1> | `library_resources_screen` | Library | filled | No | No |
| <filled_x1> | `library_returns_screen` | Library | filled | No | No |
| General | `school_memories_screen` | Memories | dropdown | No | No |
| Annual Day | `school_memories_screen` | Memories | dropdown | No | No |
| Sports Day | `school_memories_screen` | Memories | dropdown | No | No |
| Graduation | `school_memories_screen` | Memories | dropdown | No | No |
| Download | `school_memory_event_screen` | Memories | menu | Yes | Partial |
| Share link | `school_memory_event_screen` | Memories | menu | No | No |
| <text_x1> | `multi_school_portfolio_screen` | Multi-School | text | No | No |
| <icon_x3> | `multi_school_portfolio_screen` | Multi-School | icon | No | No |
| Continue | `school_onboarding_wizard_screen` | Multi-School | filled | Yes | Partial |
| <filled_x1> | `organization_builder_preview_screen` | Organization Builder | filled | No | No |
| <icon_x1> | `parent_academic_report_screen` | Parent | icon | No | No |
| Full report | `parent_dashboard_screen` | Parent | text | No | No |
| Review | `parent_experience_hub_screen` | Parent | text | Yes | Partial |
| Pay Now | `fee_summary_hero` | Parent | filled | No | No |
| Pay now | `parent_payment_screen` | Parent | filled | No | No |
| Back to fees | `parent_payment_screen` | Parent | text | No | No |
| <icon_x2> | `resource_optimization_screen` | Operations | icon | No | No |
| <icon_x1> | `branding_screen` | School Completion | icon | No | No |
| Mark topic complete | `lesson_logs_screen` | School Completion | menu | No | No |
| <fab_x1> | `room_allocation_screen` | School Completion | fab | No | No |
| <fab_x1> | `subjects_screen` | School Completion | fab | No | No |
| <filled_x2> | `syllabus_automation_screen` | School Completion | filled | No | No |
| <filled_x1> | `timetable_automation_screen` | School Completion | filled | No | No |
| Save assignment | `sis_academic_assignment_screen` | SIS | filled | No | No |
| 2025–26 | `sis_promotion_screen` | SIS | dropdown | No | No |
| 2026–27 | `sis_promotion_screen` | SIS | dropdown | No | No |
| 2027–28 | `sis_promotion_screen` | SIS | dropdown | No | No |
| 2028–29 | `sis_promotion_screen` | SIS | dropdown | No | No |
| Alphabetical | `sis_reshuffle_screen` | SIS | dropdown | No | No |
| Gender Parity | `sis_reshuffle_screen` | SIS | dropdown | No | No |
| Merit | `sis_reshuffle_screen` | SIS | dropdown | No | No |
| Q1 | `sis_section_balance_screen` | SIS | dropdown | No | No |
| Q2 | `sis_section_balance_screen` | SIS | dropdown | No | No |
| Q3 | `sis_section_balance_screen` | SIS | dropdown | No | No |
| Q4 | `sis_section_balance_screen` | SIS | dropdown | No | No |
| <filled_x1> | `sis_admissions_conversion_screen` | Admissions | filled | No | No |
| Submit | `homework_list_row` | Student | filled | Yes | Partial |
| View | `attendance_summary_card` | Teacher | text | Yes | Partial |
| Casual leave | `teacher_leave_screen` | Teacher | dropdown | No | No |
| Sick leave | `teacher_leave_screen` | Teacher | dropdown | No | No |
| Earned leave | `teacher_leave_screen` | Teacher | dropdown | No | No |
| <icon_x1> | `transport_reports_screen` | Transport | icon | No | No |
| <icon_x1> | `transport_settings_screen` | Transport | icon | No | No |
| <icon_x2> | `akshara_pagination_bar` | Other | icon | No | No |

---

## 2. Filters

| Type | Screen | Module | Patrol |
|------|--------|--------|:------:|
| dropdown | `timetable_hub_screen` | Other | No |
| chip | `admin_filter_bar` | Admin | No |
| dropdown | `admissions_workflow_actions` | Admissions | No |
| search_field | `admissions_workflow_actions` | Admissions | No |
| date | `admissions_enrollment_form_steps` | Admissions | No |
| dropdown | `admissions_fee_handoff_panel` | Admissions | No |
| dropdown | `admissions_lead_score_panel` | Admissions | No |
| dropdown | `ai_content_screen` | AI Content | No |
| chip | `login_screen` | Auth | No |
| dropdown | `staff_login_screen` | Auth | No |
| dropdown | `control_center_providers_screen` | Control Center | No |
| dropdown | `copilot_screen` | Copilot | No |
| dropdown | `dynamic_widget_layout_editor_screen` | Dynamic Widgets | No |
| dropdown | `education_screen` | Education | No |
| date | `growth_platform_screen` | Evolution | No |
| dropdown | `finance_fee_assignment_screen` | Finance | No |
| dropdown | `finance_fee_structures_screen` | Finance | No |
| dropdown | `finance_workflow_actions` | Finance | No |
| search_field | `finance_workflow_actions` | Finance | No |
| dropdown | `finance_offline_payments_screen` | Finance | No |
| search_field | `finance_student_accounts_screen` | Finance | No |
| dropdown | `homework_intelligence_screen` | Intelligence | No |
| search_field | `homework_intelligence_screen` | Intelligence | No |
| search_field | `hostel_workflow_actions` | Hostel | No |
| search_field | `hr_workflow_actions` | HR | No |
| chip | `industry_hub_screen` | Industry | No |
| search_field | `exam_intelligence_screen` | Intelligence | No |
| dropdown | `intelligence_screen` | Intelligence | No |
| search_field | `teacher_effectiveness_screen` | Intelligence | No |
| dropdown | `library_workflow_actions` | Library | No |
| search_field | `management_settings_screen` | Management | No |
| dropdown | `school_memories_screen` | Memories | No |
| chip | `multi_school_portfolio_screen` | Multi-School | No |
| chip | `notifications_screen` | Notifications | No |
| chip | `homework_filter_bar` | Parent | No |
| dropdown | `leave_apply_form` | Parent | No |
| search_field | `leave_apply_form` | Parent | No |
| chip | `notices_filter_bar` | Parent | No |
| chip | `receipt_filter_bar` | Parent | No |
| dropdown | `subject_assignment_screen` | School Completion | No |
| search_field | `subject_assignment_screen` | School Completion | No |
| dropdown | `substitute_manager_screen` | School Completion | No |
| search_field | `substitute_manager_screen` | School Completion | No |
| dropdown | `teacher_reassignment_screen` | Teacher | No |
| dropdown | `sis_academic_assignment_screen` | SIS | No |
| dropdown | `sis_promotion_screen` | SIS | No |
| search_field | `sis_promotion_screen` | SIS | No |
| dropdown | `sis_reshuffle_screen` | SIS | No |
| dropdown | `sis_section_balance_screen` | SIS | No |
| dropdown | `sis_admissions_conversion_screen` | Admissions | No |
| search_field | `sis_registry_screen` | SIS | No |
| dropdown | `teacher_homework_screen` | Teacher | No |
| dropdown | `teacher_leave_screen` | Teacher | No |
| search_field | `teacher_leave_screen` | Teacher | No |
| dropdown | `akshara_searchable_dropdown` | Other | No |
| chip | `akshara_analytics_panel` | Other | No |
| dropdown | `app_theme` | Other | No |

---

## 3. Exports (PDF / Excel / CSV / Print)

| Kind | Screen | Module | Keyed | Patrol |
|------|--------|--------|:-----:|:------:|
| export_generic | `audit_event` | Other | Partial | No |
| share | `audit_logger` | Other | Partial | No |
| export_generic | `audit_security_categorizer` | Other | Partial | No |
| share | `audit_upload_queue` | Other | Partial | No |
| share | `secure_storage_backend` | Auth | Partial | No |
| share | `dio_provider` | Other | Partial | No |
| share | `shared_preferences_provider` | Other | Partial | No |
| share | `academic_json_codec` | Other | Partial | No |
| export_generic | `audit_upload_providers` | Other | Partial | No |
| export_generic | `education_api_paths` | Education | Partial | No |
| export_generic | `education_remote_datasource` | Education | Partial | No |
| download | `api_phase5_repositories` | Other | Partial | No |
| share | `api_phase5_repositories` | Other | Partial | No |
| share | `phase5_mapper` | Other | Partial | No |
| download | `phase5_remote_datasource` | Other | Partial | No |
| share | `phase5_remote_datasource` | Other | Partial | No |
| download | `phase5_repositories` | Other | Partial | No |
| share | `phase5_repositories` | Other | Partial | No |
| export_generic | `mock_alumni_repository` | Alumni | Partial | No |
| share | `mock_hostel_repository` | Hostel | Partial | No |
| export_generic | `mock_hr_repository` | HR | Partial | No |
| download | `mock_library_repository` | Library | Partial | No |
| share | `mock_parent_meetings_repository` | Parent | Partial | Yes |
| download | `mock_phase5_repositories` | Other | Partial | No |
| share | `mock_phase5_repositories` | Other | Partial | No |
| share | `server_permission_provider` | Other | Partial | No |
| export_generic | `qa_test_keys` | Other | Partial | No |
| download | `qa_test_keys` | Other | Partial | No |
| share | `qa_test_keys` | Other | Partial | No |
| share | `admin_filter_bar` | Admin | Partial | No |
| share | `admissions_enrollment_records_provider` | Admissions | Partial | No |
| share | `admissions_fee_handoff_provider` | Admissions | Partial | No |
| share | `admissions_lead_detail_provider` | Admissions | Partial | No |
| export_generic | `admissions_reports_screen` | Admissions | Partial | No |
| share | `admissions_reports_tables` | Admissions | Partial | No |
| share | `ai_content_screen` | AI Content | Partial | No |
| export_generic | `alumni_dashboard_screen` | Alumni | Partial | No |
| download | `alumni_reports_screen` | Alumni | Partial | No |
| share | `auth_provider` | Auth | Partial | No |
| share | `auth_session_storage` | Auth | Partial | No |
| export_generic | `control_center_analytics_screen` | Control Center | Partial | No |
| export_generic | `control_center_dashboard_screen` | Control Center | Partial | No |
| share | `ai_access_preferences_storage` | Copilot | Partial | No |
| share | `copilot_ai_entry_button` | Copilot | Partial | No |
| export_generic | `director_reports_screen` | Director | Partial | No |
| pdf | `education_screen` | Education | Partial | No |
| export_generic | `education_screen` | Education | Partial | No |
| export_generic | `finance_mutations_provider` | Finance | Partial | Yes |
| export_generic | `finance_executive_dashboard_screen` | Finance | Partial | Yes |
| pdf_share | `finance_receipt_pdf_service` | Finance | Partial | Yes |
| print | `finance_receipt_pdf_service` | Finance | Partial | Yes |
| pdf | `finance_reports_screen` | Finance | Partial | Yes |
| excel | `finance_reports_screen` | Finance | Partial | Yes |
| export_generic | `finance_reports_screen` | Finance | Partial | Yes |
| export_generic | `hostel_dashboard_screen` | Hostel | Partial | No |
| download | `hostel_reports_screen` | Hostel | Partial | No |
| export_generic | `hr_dashboard_screen` | HR | Partial | No |
| export_generic | `hr_payroll_screen` | HR | Partial | No |
| export_generic | `intelligence_screen` | Intelligence | Partial | No |
| export_generic | `inventory_dashboard_screen` | Inventory | Partial | No |
| export_generic | `inventory_reports_screen` | Inventory | Partial | No |
| download | `inventory_reports_screen` | Inventory | Partial | No |
| download | `library_reports_screen` | Library | Partial | No |
| download | `library_resources_screen` | Library | Partial | No |
| export_generic | `management_dashboard_screen` | Management | Partial | Yes |
| share | `management_dashboard_screen` | Management | Partial | Yes |
| export_generic | `management_mutations_provider` | Management | Partial | Yes |
| pdf_share | `management_dashboard_pdf_service` | Management | Partial | Yes |
| export_generic | `management_dashboard_pdf_service` | Management | Partial | Yes |
| download | `school_memory_event_screen` | Memories | Partial | No |
| share | `school_memory_event_screen` | Memories | Partial | No |
| share | `attendance_models` | Parent | Partial | Yes |
| download | `parent_receipt_detail_screen` | Parent | Partial | Yes |
| share | `parent_receipt_detail_screen` | Parent | Partial | Yes |
| print | `parent_receipt_pdf_service` | Parent | Partial | Yes |
| export_generic | `phase5_models` | Other | Partial | No |
| share | `phase5_models` | Other | Partial | No |
| export_generic | `achievement_promotion_preview_screen` | Promotion | Partial | No |
| share | `achievement_promotion_preview_screen` | Promotion | Partial | No |
| export_generic | `sis_registry_screen` | SIS | Partial | No |

---

## 4. AI actions

| Kind | Screen | Module | Patrol |
|------|--------|--------|:------:|
| copilot | `ai_inference_models` | Other | Partial |
| copilot | `ai_inference_pipeline` | Other | Partial |
| generate | `edge_ai_provider` | Other | Partial |
| recommend | `edge_ai_provider` | Other | Partial |
| copilot | `edge_ai_provider` | Other | Partial |
| copilot | `stub_ai_provider` | Other | Partial |
| generate | `audit_event` | Other | Partial |
| copilot | `audit_event` | Other | Partial |
| generate | `audit_security_categorizer` | Other | Partial |
| copilot | `audit_security_categorizer` | Other | Partial |
| draft | `continuity_models` | Continuity | Partial |
| copilot | `industry_capability_registry` | Industry | Partial |
| draft | `industry_context_provider` | Industry | Partial |
| generate | `correlation_id_interceptor` | Other | Partial |
| optimize | `provider_rebuild_registry` | Other | Partial |
| optimize | `repository_cache` | Other | Partial |
| generate | `api_accommodation_repository` | Accommodation | Partial |
| recommend | `api_accommodation_repository` | Accommodation | Partial |
| generate | `api_admissions_repository` | Admissions | Partial |
| draft | `admissions_enum_codec` | Admissions | Partial |
| generate | `enrollment_request_dto` | Admissions | Partial |
| generate | `admissions_mapper` | Admissions | Partial |
| generate | `admissions_api_paths` | Admissions | Partial |
| generate | `admissions_remote_datasource` | Admissions | Partial |
| generate | `alumni_mapper` | Alumni | Partial |
| recommend | `api_analytics_intelligence_repository` | Intelligence | Yes |
| recommend | `analytics_intelligence_dto` | Intelligence | Yes |
| recommend | `hybrid_analytics_intelligence_repository` | Intelligence | Yes |
| recommend | `analytics_intelligence_mapper` | Intelligence | Yes |
| recommend | `analytics_intelligence_api_paths` | Intelligence | Yes |
| recommend | `analytics_intelligence_remote_datasource` | Intelligence | Yes |
| copilot | `api_repository_providers` | Other | Partial |
| draft | `continuity_mapper` | Continuity | Partial |
| copilot | `api_copilot_repository` | Copilot | Partial |
| copilot | `copilot_dto` | Copilot | Partial |
| copilot | `hybrid_copilot_repository` | Copilot | Partial |
| copilot | `copilot_mapper` | Copilot | Partial |
| copilot | `copilot_api_paths` | Copilot | Partial |
| copilot | `copilot_remote_datasource` | Copilot | Partial |
| generate | `api_director_repository` | Director | Yes |
| generate | `api_education_repository` | Education | Partial |
| generate | `hybrid_education_repository` | Education | Partial |
| generate | `education_mapper` | Education | Partial |
| draft | `education_mapper` | Education | Partial |
| generate | `education_api_paths` | Education | Partial |
| generate | `education_remote_datasource` | Education | Partial |
| generate | `api_evolution_repository` | Evolution | Partial |
| generate | `hybrid_evolution_repository` | Evolution | Partial |
| recommend | `evolution_mapper` | Evolution | Partial |
| generate | `evolution_api_paths` | Evolution | Partial |
| generate | `evolution_remote_datasource` | Evolution | Partial |
| copilot | `api_finance_repository` | Finance | Partial |
| draft | `finance_enum_codec` | Finance | Partial |
| copilot | `hybrid_finance_repository` | Finance | Partial |
| generate | `finance_intelligence_mapper` | Finance | Partial |
| copilot | `finance_intelligence_mapper` | Finance | Partial |
| generate | `finance_mapper` | Finance | Partial |
| copilot | `finance_api_paths` | Finance | Partial |
| copilot | `finance_remote_datasource` | Finance | Partial |
| generate | `api_healthcare_repository` | Healthcare | Partial |
| recommend | `api_healthcare_repository` | Healthcare | Partial |
| generate | `hostel_mapper` | Hostel | Partial |
| draft | `hr_enum_codec` | HR | Partial |
| generate | `api_intelligence_repository` | Intelligence | Yes |
| draft | `api_intelligence_repository` | Intelligence | Yes |
| generate | `hybrid_intelligence_repository` | Intelligence | Yes |
| draft | `hybrid_intelligence_repository` | Intelligence | Yes |
| recommend | `intelligence_mapper` | Intelligence | Yes |
| draft | `intelligence_mapper` | Intelligence | Yes |
| generate | `intelligence_api_paths` | Intelligence | Yes |
| generate | `intelligence_remote_datasource` | Intelligence | Yes |
| copilot | `api_inventory_repository` | Inventory | Partial |
| draft | `inventory_enum_codec` | Inventory | Partial |
| generate | `inventory_intelligence_mapper` | Inventory | Partial |
| recommend | `inventory_intelligence_mapper` | Inventory | Partial |
| copilot | `inventory_intelligence_mapper` | Inventory | Partial |
| generate | `inventory_mapper` | Inventory | Partial |
| copilot | `inventory_api_paths` | Inventory | Partial |
| copilot | `inventory_remote_datasource` | Inventory | Partial |
| draft | `inventory_finance_dto` | Finance | Partial |
| draft | `inventory_finance_mapper` | Finance | Partial |
| generate | `library_mapper` | Library | Partial |
| recommend | `management_enum_codec` | Management | Partial |
| recommend | `management_mapper` | Management | Partial |
| draft | `api_multi_school_operations_repository` | Multi-School | Partial |
| draft | `multi_school_operations_remote_datasource` | Multi-School | Partial |
| generate | `api_organization_builder_repository` | Organization Builder | Partial |
| recommend | `api_organization_builder_repository` | Organization Builder | Partial |
| draft | `api_organization_builder_repository` | Organization Builder | Partial |
| draft | `organization_builder_api_paths` | Organization Builder | Partial |
| generate | `organization_builder_remote_datasource` | Organization Builder | Partial |
| draft | `organization_builder_remote_datasource` | Organization Builder | Partial |
| generate | `api_parent_repository` | Parent | Partial |
| recommend | `api_parent_repository` | Parent | Partial |
| generate | `api_phase4_repositories` | Other | Partial |
| recommend | `phase4_mapper` | Other | Partial |
| generate | `phase4_remote_datasource` | Other | Partial |
| generate | `api_phase5_repositories` | Other | Partial |
| recommend | `phase5_mapper` | Other | Partial |
| draft | `phase5_mapper` | Other | Partial |
| generate | `phase5_remote_datasource` | Other | Partial |
| generate | `api_platform_intelligence_repository` | Intelligence | Yes |
| recommend | `api_platform_intelligence_repository` | Intelligence | Yes |
| recommend | `platform_intelligence_mapper` | Intelligence | Yes |
| generate | `api_platform_operations_repository` | Platform Operations | Partial |
| recommend | `api_platform_operations_repository` | Platform Operations | Partial |
| recommend | `platform_operations_api_paths` | Platform Operations | Partial |
| recommend | `platform_operations_remote_datasource` | Platform Operations | Partial |
| generate | `api_restaurant_repository` | Restaurant | Partial |
| recommend | `api_restaurant_repository` | Restaurant | Partial |
| generate | `api_salon_repository` | Salon | Partial |
| recommend | `api_salon_repository` | Salon | Partial |
| generate | `api_school_completion_repository` | School Completion | Partial |
| recommend | `api_school_completion_repository` | School Completion | Partial |
| recommend | `apply_timetable_optimization_request_dto` | School Completion | Partial |
| generate | `hybrid_school_completion_repository` | School Completion | Partial |
| recommend | `hybrid_school_completion_repository` | School Completion | Partial |
| generate | `school_completion_mapper` | School Completion | Partial |
| recommend | `school_completion_mapper` | School Completion | Partial |
| generate | `school_completion_api_paths` | School Completion | Partial |
