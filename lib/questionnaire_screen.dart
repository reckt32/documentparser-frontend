import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';

/// Predefined goal types for financial planning
const List<String> kGoalTypes = [
  'Children\'s Education',
  'Children\'s Marriage',
  'Vacation',
  'Home Purchase',
  'Lifestyle (Bike/Car/etc)',
  'Retirement Corpus',
  'Emergency Fund',
  'Wealth Creation',
  'Medical/Healthcare',
  'Home Renovation',
  'Debt Repayment',
  'Business/Startup',
  'Wedding',
  'Inheritance/Legacy',
  'Charity/Philanthropy',
  'Other',
];

/// Multi-step financial questionnaire.
/// Sections: personal_info, family_info, goals, risk_profile, insurance, lifestyle, estate (placeholder).
/// Branching rules:
/// - maritalStatus == Married => spouse fields
/// - childrenCount > 0 => children list
/// - hasDependents == true => dependents list
/// - addGoals == true => dynamic goals
class QuestionnaireScreen extends StatefulWidget {
  final String backendUrl;
  final int? questionnaireId;
  final ValueChanged<int> onQuestionnaireStarted;
  final VoidCallback? onCompleted;
  final Map<String, dynamic>? prefillData;

  const QuestionnaireScreen({
    super.key,
    required this.backendUrl,
    required this.onQuestionnaireStarted,
    this.questionnaireId,
    this.onCompleted,
    this.prefillData,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _stepIndex = 0;
  int? _qid;
  String? _planUrl;

  // Track which fields were auto-populated by prefill so we can highlight them
  final Set<String> _prefilledFields = {};

  // Personal Info
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _maritalStatus = 'Single';

  // Family Info
  final _spouseNameCtrl = TextEditingController();
  int _childrenCount = 0;
  final List<Map<String, TextEditingController>> _childrenCtrls = [];
  bool _hasDependents = false;
  final List<Map<String, TextEditingController>> _dependentsCtrls = [];

  // Goals
  bool _addGoals = true;
  final List<Map<String, TextEditingController>> _goalCtrls = [];
  final List<String> _goalTypes = []; // Selected goal type for each goal
  // Per-goal risk profile settings
  final List<String> _goalRiskTolerances = [];
  final List<String> _goalImportances = [];
  final List<String> _goalFlexibilities = [];
  final List<String> _goalBehaviors = [];
  
  // Retirement Planning
  bool _wantsRetirementPlanning = false;
  final _desiredMonthlyPensionCtrl = TextEditingController();

  // Risk Profile
  String _riskTolerance = 'Medium';
  String _primaryHorizon = 'Medium';
  // Advanced risk inputs
  final _lossToleranceCtrl = TextEditingController();
  final _primaryHorizonYearsCtrl = TextEditingController();
  String _goalImportance = 'Important';
  String _goalFlexibility = 'Fixed';
  String _behavior = 'Hold';
  String _incomeStability = 'Average';
  final _emergencyFundMonthsCtrl = TextEditingController();
  final _equityAllocationCtrl = TextEditingController();

  // Insurance (used for term insurance calculations)
  final _lifeCoverCtrl = TextEditingController();
  final _healthCoverCtrl = TextEditingController();
  // Insurance confirmation checkboxes
  bool _hasTermInsuranceConfirmed = false;
  bool _hasHealthInsuranceConfirmed = false;

  // Lifestyle
  final _annualIncomeCtrl = TextEditingController();
  final _monthlyExpensesCtrl = TextEditingController();
  final _monthlyEmiCtrl = TextEditingController();
  final _emergencyFundCtrl = TextEditingController();
  final _availableSavingsCtrl = TextEditingController();
  final _savingsPercentCtrl = TextEditingController();
  String _savingsBand = '';
  final List<String> _currentProducts = [];
  final Map<String, TextEditingController> _allocationCtrls = {
    'equity': TextEditingController(),
    'debt': TextEditingController(),
    'gold': TextEditingController(),
    'realEstate': TextEditingController(),
    'insuranceLinked': TextEditingController(),
    'cash': TextEditingController(),
  };

  // Estate
  String _willStatus = 'Not Applicable';
  final List<Map<String, TextEditingController>> _nomineeCtrls = [];

  bool _loading = false;
  bool _isGeneratingReport = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    print('[QuestionnaireScreen] initState called');
    print('[QuestionnaireScreen] widget.questionnaireId: ${widget.questionnaireId}');
    print('[QuestionnaireScreen] widget.prefillData: ${widget.prefillData}');
    _qid = widget.questionnaireId;
    // Apply prefill values from uploaded document insights, if any
    _applyPrefill(widget.prefillData);
    if (_qid != null) {
      _fetchQuestionnaire();
    } else {
      _startQuestionnaire(); // auto-start so the form appears immediately
    }
  }

  @override
  void didUpdateWidget(covariant QuestionnaireScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[QuestionnaireScreen] didUpdateWidget called');
    print('[QuestionnaireScreen] old prefillData: ${oldWidget.prefillData}');
    print('[QuestionnaireScreen] new prefillData: ${widget.prefillData}');
    print('[QuestionnaireScreen] old questionnaireId: ${oldWidget.questionnaireId}');
    print('[QuestionnaireScreen] new questionnaireId: ${widget.questionnaireId}');
    
    // If prefillData changed and new data is available, apply it
    if (widget.prefillData != oldWidget.prefillData && widget.prefillData != null) {
      print('[QuestionnaireScreen] Prefill data changed, applying new prefill...');
      _applyPrefill(widget.prefillData);
    }
    
    // If questionnaireId changed from null to a value, fetch questionnaire
    if (widget.questionnaireId != oldWidget.questionnaireId) {
      print('[QuestionnaireScreen] Questionnaire ID changed from ${oldWidget.questionnaireId} to ${widget.questionnaireId}');
      _qid = widget.questionnaireId;
      if (_qid != null && oldWidget.questionnaireId == null) {
        _fetchQuestionnaire();
      }
    }
  }

  Future<void> _startQuestionnaire() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _statusMessage = 'Starting questionnaire...';
    });
    try {
      final resp = await http.post(
        Uri.parse('${widget.backendUrl}/questionnaire/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 'user'}),
      );
if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        final id = data['questionnaire_id'] as int;
        setState(() {
          _qid = id;
          _statusMessage = 'Questionnaire started (ID $id).';
        });
        widget.onQuestionnaireStarted(id);
        // Immediately fetch prefill suggestions for the newly created questionnaire
        await _fetchQuestionnaire();
      } else {
        setState(() {
          _statusMessage = 'Failed to start: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Helper function to safely convert dynamic maps to Map<String, dynamic>
  // This is needed because JSON decoding on web returns LinkedMap<dynamic, dynamic>
  Map<String, dynamic> _toStringDynamicMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  void _applyPrefill(Map<String, dynamic>? prefill) {
    print('[_applyPrefill] Called with prefill: $prefill');
    if (prefill == null) {
      print('[_applyPrefill] Prefill is null, returning early');
      return;
    }
    if (prefill.isEmpty) {
      print('[_applyPrefill] Prefill is empty map, returning early');
      return;
    }
    try {
      print('[_applyPrefill] Prefill keys: ${prefill.keys.toList()}');
      final di = _toStringDynamicMap(prefill['docInsights'] ?? prefill['docinsights']);
      print('[_applyPrefill] docInsights: $di');
      final bank = _toStringDynamicMap(di['bank']);
      print('[_applyPrefill] bank: $bank');
      final portfolio = _toStringDynamicMap(di['portfolio']);
      print('[_applyPrefill] portfolio: $portfolio');
      final analysis = _toStringDynamicMap(prefill['analysis']);
      print('[_applyPrefill] analysis: $analysis');
      // Direct prefill sections from backend
      final lifestyle = _toStringDynamicMap(prefill['lifestyle']);
      print('[_applyPrefill] lifestyle: $lifestyle');
      final allocPrefill = _toStringDynamicMap(prefill['allocation']);
      print('[_applyPrefill] allocation: $allocPrefill');
      final insurancePrefill = _toStringDynamicMap(prefill['insurance']);
      print('[_applyPrefill] insurance: $insurancePrefill');

      bool changedBand = false;
      int appliedCount = 0;

      // Lifestyle prefill from backend 'lifestyle' first, then bank totals
      final inflow = bank['total_inflows'];
      final outflow = bank['total_outflows'];
      final netcf = bank['net_cashflow'];
      // Backend-provided lifestyle overrides, if present
      final lfAnnual = lifestyle['annual_income'];
      final lfMonthlyExp = lifestyle['monthly_expenses'];
      final lfSavingsPct = lifestyle['savings_percent'];

      String _fmtNum(dynamic v) {
        if (v == null) return '';
        if (v is num) return v.toString();
        return v.toString();
      }

      // Annual income: prefer backend lifestyle. Else ≈ total inflows
      if (_annualIncomeCtrl.text.trim().isEmpty) {
        if (lfAnnual != null) {
          _annualIncomeCtrl.text = _fmtNum(lfAnnual);
          _prefilledFields.add('annual_income');
          appliedCount++;
        } else if (inflow != null) {
          _annualIncomeCtrl.text = _fmtNum(inflow);
          _prefilledFields.add('annual_income');
          appliedCount++;
        }
      }
      // Monthly expenses: prefer backend lifestyle. Else ≈ total outflows / 12
      if (_monthlyExpensesCtrl.text.trim().isEmpty) {
        try {
          if (lfMonthlyExp != null) {
            if (lfMonthlyExp is num) {
              _monthlyExpensesCtrl.text = lfMonthlyExp.toStringAsFixed(2);
              _prefilledFields.add('monthly_expenses');
              appliedCount++;
            } else {
              final parsed = double.tryParse(lfMonthlyExp.toString().replaceAll(',', ''));
              if (parsed != null) {
                _monthlyExpensesCtrl.text = parsed.toStringAsFixed(2);
                _prefilledFields.add('monthly_expenses');
                appliedCount++;
              }
            }
          } else if (outflow != null) {
            if (outflow is num) {
              _monthlyExpensesCtrl.text = (outflow / 12.0).toStringAsFixed(2);
              _prefilledFields.add('monthly_expenses');
              appliedCount++;
            } else {
              final parsed = double.tryParse(outflow.toString().replaceAll(',', ''));
              if (parsed != null) {
                _monthlyExpensesCtrl.text = (parsed / 12.0).toStringAsFixed(2);
                _prefilledFields.add('monthly_expenses');
                appliedCount++;
              }
            }
          }
        } catch (_) {}
      }
      // Savings %: prefer backend lifestyle. Else ≈ max(0, net cf / inflow * 100)
      if (_savingsPercentCtrl.text.trim().isEmpty) {
        try {
          if (lfSavingsPct != null) {
            final sp =
                (lfSavingsPct is num)
                    ? lfSavingsPct.toDouble()
                    : double.tryParse(lfSavingsPct.toString().replaceAll(',', ''));
            if (sp != null && sp.isFinite) {
              _savingsPercentCtrl.text = sp.toStringAsFixed(2);
              _prefilledFields.add('savings_percent');
              appliedCount++;
            }
          } else if (inflow != null && netcf != null) {
            final inflowNum =
                (inflow is num)
                    ? inflow.toDouble()
                    : double.tryParse(inflow.toString().replaceAll(',', '')) ??
                        0.0;
            final netNum =
                (netcf is num)
                    ? netcf.toDouble()
                    : double.tryParse(netcf.toString().replaceAll(',', '')) ??
                        0.0;
            if (inflowNum > 0) {
              final sp = (netNum / inflowNum) * 100.0;
              _savingsPercentCtrl.text = sp.isFinite ? sp.toStringAsFixed(2) : '';
              if (sp.isFinite) { _prefilledFields.add('savings_percent'); appliedCount++; }
            }
          }
        } catch (_) {}
      }

      // Monthly EMI prefill from backend lifestyle
      if (_monthlyEmiCtrl.text.trim().isEmpty) {
        final lfMonthlyEmi = lifestyle['monthly_emi'];
        if (lfMonthlyEmi != null) {
          _monthlyEmiCtrl.text = _fmtNum(lfMonthlyEmi);
          _prefilledFields.add('monthly_emi');
          print('[_applyPrefill] Prefilled monthly EMI: ${_monthlyEmiCtrl.text}');
          appliedCount++;
        }
      }

      // Insurance prefill: prefer backend insurance section, then analysis-derived
      final insFromAnalysis = _toStringDynamicMap(analysis['insurance']);
      if (_lifeCoverCtrl.text.trim().isEmpty) {
        final lc = insurancePrefill['life_cover'] ?? insFromAnalysis['lifeCover'];
        if (lc != null) {
          _lifeCoverCtrl.text = _fmtNum(lc);
          _prefilledFields.add('life_cover');
          appliedCount++;
        }
      }
      if (_healthCoverCtrl.text.trim().isEmpty) {
        final hc = insurancePrefill['health_cover'] ?? insFromAnalysis['healthCover'];
        if (hc != null) {
          _healthCoverCtrl.text = _fmtNum(hc);
          _prefilledFields.add('health_cover');
          appliedCount++;
        }
      }
      // Insurance confirmation checkboxes prefill
      final termConfirmed = insurancePrefill['has_term_insurance_confirmed'];
      if (termConfirmed != null && termConfirmed is bool) {
        _hasTermInsuranceConfirmed = termConfirmed;
        appliedCount++;
      }
      final healthConfirmed = insurancePrefill['has_health_insurance_confirmed'];
      if (healthConfirmed != null && healthConfirmed is bool) {
        _hasHealthInsuranceConfirmed = healthConfirmed;
        appliedCount++;
      }

      // Available savings prefill from lifestyle
      if (_availableSavingsCtrl.text.trim().isEmpty) {
        final avs = lifestyle['available_savings'];
        if (avs != null) {
          _availableSavingsCtrl.text = _fmtNum(avs);
          _prefilledFields.add('available_savings');
          print('[_applyPrefill] Prefilled available savings: ${_availableSavingsCtrl.text}');
          appliedCount++;
        }
      }

      // Allocation prefill: prefer backend 'allocation', then portfolio allocation (best-effort)
      final alloc = allocPrefill.isNotEmpty ? allocPrefill : _toStringDynamicMap(portfolio['allocation']);
      void setAlloc(String key, TextEditingController c) {
        final v = alloc[key];
        if (c.text.trim().isEmpty && v != null) {
          c.text = _fmtNum(v);
          _prefilledFields.add('alloc_$key');
          appliedCount++;
        }
      }

      setAlloc('equity', _allocationCtrls['equity']!);
      setAlloc('debt', _allocationCtrls['debt']!);
      setAlloc('gold', _allocationCtrls['gold']!);
      setAlloc('realEstate', _allocationCtrls['realEstate']!);
      setAlloc('insuranceLinked', _allocationCtrls['insuranceLinked']!);
      setAlloc('cash', _allocationCtrls['cash']!);

      // Basic risk hints from analysis
      final adv = _toStringDynamicMap(analysis['advancedRisk']);
      if (_equityAllocationCtrl.text.trim().isEmpty) {
        final mid = adv['recommendedEquityMid'];
        if (mid != null) {
          _equityAllocationCtrl.text = _fmtNum(mid);
          _prefilledFields.add('equity_allocation');
          appliedCount++;
        }
      }

      // Optionally mark savings band based on savings percent
      if (_savingsBand.isEmpty && _savingsPercentCtrl.text.isNotEmpty) {
        try {
          final sp = double.tryParse(_savingsPercentCtrl.text) ?? 0.0;
          if (sp < 10)
            _savingsBand = '<10%';
          else if (sp < 20)
            _savingsBand = '10-20%';
          else if (sp < 30)
            _savingsBand = '20-30%';
          else
            _savingsBand = '>30%';
          changedBand = true;
        } catch (_) {}
      }

      // PAN/name/age prefill from backend personal_info, or ITR/CAS if present in analysis/docInsights (best-effort)
      final personalFromBackend = _toStringDynamicMap(prefill['personal_info']);
      final personalFromAnalysis = _toStringDynamicMap(analysis['personal']);
      print('[_applyPrefill] personalFromBackend: $personalFromBackend');
      print('[_applyPrefill] personalFromAnalysis: $personalFromAnalysis');
      
      // Name prefill: prefer backend personal_info, then analysis
      if (_nameCtrl.text.trim().isEmpty) {
        final name = personalFromBackend['name'] ?? personalFromAnalysis['name'];
        if (name != null) {
          _nameCtrl.text = name.toString();
          _prefilledFields.add('name');
          print('[_applyPrefill] Prefilled name: ${_nameCtrl.text}');
          appliedCount++;
        }
      }
      // Age prefill: prefer backend personal_info, then analysis
      if (_ageCtrl.text.trim().isEmpty) {
        final age = personalFromBackend['age'] ?? personalFromAnalysis['age'];
        if (age != null) {
          _ageCtrl.text = age.toString();
          _prefilledFields.add('age');
          print('[_applyPrefill] Prefilled age: ${_ageCtrl.text}');
          appliedCount++;
        }
      }
      // PAN prefill
      if (_panCtrl.text.trim().isEmpty) {
        final pan = personalFromBackend['pan'] ?? personalFromAnalysis['pan'];
        if (pan != null) {
          _panCtrl.text = pan.toString();
          _prefilledFields.add('pan');
          print('[_applyPrefill] Prefilled PAN: ${_panCtrl.text}');
          appliedCount++;
        }
      }
      // DOB prefill
      if (_dobCtrl.text.trim().isEmpty) {
        final dob = personalFromBackend['dob'] ?? personalFromAnalysis['dob'];
        if (dob != null) {
          _dobCtrl.text = dob.toString();
          _prefilledFields.add('dob');
          print('[_applyPrefill] Prefilled DOB: ${_dobCtrl.text}');
          appliedCount++;
        }
      }
      // Contact prefill
      if (_contactCtrl.text.trim().isEmpty) {
        final contact = personalFromBackend['contact'] ?? personalFromBackend['email'] ?? personalFromBackend['phone'] ?? personalFromAnalysis['contact'];
        if (contact != null) {
          _contactCtrl.text = contact.toString();
          _prefilledFields.add('contact');
          print('[_applyPrefill] Prefilled contact: ${_contactCtrl.text}');
          appliedCount++;
        }
      }
      // trigger a rebuild so dropdowns/derived labels reflect prefill in Flutter Web
      print('[_applyPrefill] Applied $appliedCount fields, changedBand: $changedBand');
      if (mounted) {
        setState(() {
          _statusMessage = appliedCount > 0
              ? 'Prefill applied ($appliedCount fields).'
              : 'No prefill available.';
        });
      }
    } catch (e, stackTrace) {
      print('[_applyPrefill] Error: $e');
      print('[_applyPrefill] Stack trace: $stackTrace');
    }
  }

  Future<void> _fetchQuestionnaire() async {
    print('[_fetchQuestionnaire] Called with _qid: $_qid');
    if (_qid == null) {
      print('[_fetchQuestionnaire] _qid is null, returning early');
      return;
    }
    try {
      print('[_fetchQuestionnaire] Fetching questionnaire from ${widget.backendUrl}/questionnaire/$_qid');
      final resp = await http.get(
        Uri.parse('${widget.backendUrl}/questionnaire/${_qid}'),
      );
      print('[_fetchQuestionnaire] Questionnaire response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        print('[_fetchQuestionnaire] Questionnaire response body: ${resp.body}');
        // Could hydrate fields if needed in future.
      }
      // Fetch prefill suggestions from backend and apply
      print('[_fetchQuestionnaire] Fetching prefill from ${widget.backendUrl}/questionnaire/$_qid/prefill');
      final prefillResp = await http.get(
        Uri.parse('${widget.backendUrl}/questionnaire/${_qid}/prefill'),
      );
      print('[_fetchQuestionnaire] Prefill response status: ${prefillResp.statusCode}');
      print('[_fetchQuestionnaire] Prefill response body: ${prefillResp.body}');
      if (prefillResp.statusCode == 200) {
        final data = jsonDecode(prefillResp.body) as Map<String, dynamic>;
        print('[_fetchQuestionnaire] Parsed prefill data: $data');
        _applyPrefill(data);
        setState(() {
          _statusMessage = 'Prefill applied from documents.';
        });
      } else {
        print('[_fetchQuestionnaire] Prefill request failed with status: ${prefillResp.statusCode}');
      }
    } catch (e, stackTrace) {
      print('[_fetchQuestionnaire] Error: $e');
      print('[_fetchQuestionnaire] Stack trace: $stackTrace');
    }
  }

  Future<void> _saveSection(
    String section,
    Map<String, dynamic> payload,
  ) async {
    if (_qid == null) {
      setState(() {
        _statusMessage = 'Start questionnaire first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = 'Saving $section...';
    });
    try {
      final resp = await http.put(
        Uri.parse('${widget.backendUrl}/questionnaire/${_qid}/$section'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200) {
        setState(() {
          _statusMessage = '$section saved.';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to save $section: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error saving $section: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Auto-save current section on navigation
  Future<void> _autoSaveCurrentSection() async {
    if (_qid == null) return;
    switch (_stepIndex) {
      case 0:
        await _saveSection('personal_info', {
          'name': _nameCtrl.text.trim(),
          'age': _ageCtrl.text.trim(),
          'pan': _panCtrl.text.trim(),
          'dob': _dobCtrl.text.trim(),
          'contact': _contactCtrl.text.trim(),
          'marital_status': _maritalStatus,
        });
        break;
      case 1:
        await _saveSection('family_info', {
          'spouse': _maritalStatus == 'Married' ? _spouseNameCtrl.text.trim() : null,
          'children': _childrenCtrls
              .map((m) => {
                    'name': m['name']!.text.trim(),
                    'age': m['age']!.text.trim(),
                  })
              .toList(),
          'dependents': _hasDependents
              ? _dependentsCtrls
                  .map((m) => {
                        'name': m['name']!.text.trim(),
                        'relation': m['relation']!.text.trim(),
                      })
                  .toList()
              : [],
        });
        break;
      case 2:
        await _saveSection('goals', {
          'items': _addGoals
              ? List.generate(_goalCtrls.length, (i) {
                  final g = _goalCtrls[i];
                  return {
                    'name': i < _goalTypes.length ? _goalTypes[i] : '',
                    'target_amount': g['target_amount']!.text.trim(),
                    'horizon_years': g['horizon_years']!.text.trim(),
                    'suggested_strategy': g['suggested_strategy']!.text.trim(),
                    // Per-goal risk profile
                    'risk_tolerance': i < _goalRiskTolerances.length ? _goalRiskTolerances[i].toLowerCase() : 'medium',
                    'goal_importance': i < _goalImportances.length ? _goalImportances[i].toLowerCase() : 'important',
                    'goal_flexibility': i < _goalFlexibilities.length ? _goalFlexibilities[i].toLowerCase() : 'fixed',
                    'behavior': i < _goalBehaviors.length ? _goalBehaviors[i].toLowerCase() : 'hold',
                  };
                })
              : [],
          'wants_retirement_planning': _wantsRetirementPlanning,
          'desired_monthly_pension': _desiredMonthlyPensionCtrl.text.trim(),
        });
        break;
      case 3:
        await _saveSection('risk_profile', {
          'tolerance': _riskTolerance.toLowerCase(),
          'primary_horizon': _primaryHorizon.toLowerCase(),
          'primary_horizon_years': _primaryHorizonYearsCtrl.text.trim(),
          'loss_tolerance_percent': _lossToleranceCtrl.text.trim(),
          'goal_importance': _goalImportance.toLowerCase(),
          'goal_flexibility': _goalFlexibility.toLowerCase(),
          'behavior': _behavior.toLowerCase(),
          'income_stability': _incomeStability.toLowerCase(),
          'emergency_fund_months': _emergencyFundMonthsCtrl.text.trim(),
          'equity_allocation_percent': _equityAllocationCtrl.text.trim(),
        });
        break;
      case 4:
        await _saveSection('insurance', {
          'life_cover': _lifeCoverCtrl.text.trim(),
          'health_cover': _healthCoverCtrl.text.trim(),
          'has_term_insurance_confirmed': _hasTermInsuranceConfirmed,
          'has_health_insurance_confirmed': _hasHealthInsuranceConfirmed,
        });
        break;
      case 5:
        await _saveSection('lifestyle', {
          'annual_income': _annualIncomeCtrl.text.trim(),
          'monthly_expenses': _monthlyExpensesCtrl.text.trim(),
          'monthly_emi': _monthlyEmiCtrl.text.trim(),
          'emergency_fund': _emergencyFundCtrl.text.trim(),
          'available_savings': _availableSavingsCtrl.text.trim(),
          'savings_percent': _savingsPercentCtrl.text.trim(),
          'savings_band': _savingsBand,
          'products': _currentProducts,
          'allocation': {
            for (final e in _allocationCtrls.entries)
              if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
          },
        });
        break;
      case 6:
        await _saveSection('estate', {
          'will_status': _willStatus,
          'nominees': _nomineeCtrls
              .map((n) => {
                    'name': n['name']!.text.trim(),
                    'relation': n['relation']!.text.trim(),
                    'allocation_percent': n['allocation']!.text.trim(),
                  })
              .toList(),
        });
        break;
      default:
        break;
    }
  }

  Future<void> _generateReport() async {
    if (_qid == null) {
      setState(() {
        _statusMessage = 'Start questionnaire first.';
      });
      return;
    }
    setState(() {
      _isGeneratingReport = true;
      _statusMessage = 'Generating financial report...';
      _planUrl = null;
    });
    try {
      // Get auth token for authorized request
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      if (token == null) {
        setState(() {
          _isGeneratingReport = false;
          _statusMessage = 'Not authenticated. Please log in again.';
        });
        return;
      }

      final resp = await http.post(
        Uri.parse('${widget.backendUrl}/report/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'questionnaire_id': _qid, 'useLLM': true}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final pdfUrl = data['financial_plan_pdf_url'] as String?;
        final remainingCredits = data['remaining_credits'] ?? 0;
        setState(() {
          _isGeneratingReport = false;
          _planUrl = pdfUrl;
          _statusMessage = 'Report ready! Credits remaining: $remainingCredits';
        });
        // Auto-open the PDF in a new tab
        if (pdfUrl != null) {
          final uri = Uri.parse(pdfUrl);
          await launchUrl(uri, webOnlyWindowName: '_blank');
        }
        // Refresh auth state to update credit count across the app
        await authService.refreshPaymentStatus();
      } else if (resp.statusCode == 402) {
        setState(() {
          _isGeneratingReport = false;
          _statusMessage = 'No report credits remaining. Redirecting to payment...';
        });
        // Refresh payment status so AuthWrapper redirects to PaymentScreen
        await authService.refreshPaymentStatus();
      } else {
        setState(() {
          _isGeneratingReport = false;
          _statusMessage = 'Failed: ${resp.statusCode} ${resp.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isGeneratingReport = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _openPlan() async {
    if (_planUrl == null) return;
    final uri = Uri.parse(_planUrl!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Section builders

  Widget _buildPersonalInfo() {
    final hasPersonalPrefill = _prefilledFields.intersection({'name', 'age', 'pan', 'dob', 'contact'}).isNotEmpty;
    return _sectionCard(
      title: 'Personal Info',
      showPrefillWarning: hasPersonalPrefill,
      children: [
        _textField(_nameCtrl, 'Name', isPrefilled: _prefilledFields.contains('name')),
        _textField(_ageCtrl, 'Age (years)', keyboard: TextInputType.number, isPrefilled: _prefilledFields.contains('age')),
        _textField(_panCtrl, 'PAN', isPrefilled: _prefilledFields.contains('pan')),
        _textField(_dobCtrl, 'Date of Birth (YYYY-MM-DD)', isPrefilled: _prefilledFields.contains('dob')),
        _textField(_contactCtrl, 'Contact (Email/Phone)', isPrefilled: _prefilledFields.contains('contact')),
        _dropdown<String>(
          label: 'Marital Status',
          value: _maritalStatus,
          items: const ['Single', 'Married', 'Other'],
          onChanged: (v) => setState(() => _maritalStatus = v),
        ),
        _saveButton(() {
          _saveSection('personal_info', {
            'name': _nameCtrl.text.trim(),
            'age': _ageCtrl.text.trim(),
            'pan': _panCtrl.text.trim(),
            'dob': _dobCtrl.text.trim(),
            'contact': _contactCtrl.text.trim(),
            'marital_status': _maritalStatus,
          });
        }),
      ],
    );
  }

  Widget _buildFamilyInfo() {
    return _sectionCard(
      title: 'Family & Dependents',
      children: [
        if (_maritalStatus == 'Married')
          _textField(_spouseNameCtrl, 'Spouse Name'),
        Row(
          children: [
            Expanded(
              child: _numberStepper(
                label: 'Children',
                value: _childrenCount,
                onChanged: (v) {
                  setState(() {
                    _childrenCount = v;
                    while (_childrenCtrls.length < v) {
                      _childrenCtrls.add({
                        'name': TextEditingController(),
                        'age': TextEditingController(),
                      });
                    }
                    while (_childrenCtrls.length > v) {
                      _childrenCtrls.removeLast();
                    }
                  });
                },
                max: 10,
              ),
            ),
          ],
        ),
        for (int i = 0; i < _childrenCtrls.length; i++)
          _inlineRow([
            Expanded(
              child: _textField(
                _childrenCtrls[i]['name']!,
                'Child ${i + 1} Name',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _textField(
                _childrenCtrls[i]['age']!,
                'Age',
                keyboard: TextInputType.number,
              ),
            ),
          ]),
        SwitchListTile(
          title: const Text('Other Dependents?'),
          value: _hasDependents,
          onChanged: (v) {
            setState(() {
              _hasDependents = v;
              if (!v) _dependentsCtrls.clear();
            });
          },
        ),
        if (_hasDependents)
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _dependentsCtrls.add({
                      'name': TextEditingController(),
                      'relation': TextEditingController(),
                    });
                  });
                },
                child: const Text('Add Dependent'),
              ),
              for (int i = 0; i < _dependentsCtrls.length; i++)
                _inlineRow([
                  Expanded(
                    child: _textField(
                      _dependentsCtrls[i]['name']!,
                      'Dependent ${i + 1} Name',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      _dependentsCtrls[i]['relation']!,
                      'Relation',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        _dependentsCtrls.removeAt(i);
                      });
                    },
                  ),
                ]),
            ],
          ),
        // Term Insurance Information (shown when there are financial dependents)
        if (_childrenCount > 0 || (_hasDependents && _dependentsCtrls.isNotEmpty))
          Builder(builder: (context) {
            double age = double.tryParse(_ageCtrl.text.trim()) ?? 30;
            double monthlyIncome = (double.tryParse(_annualIncomeCtrl.text.trim()) ?? 0) / 12;
            double currentLifeCover = double.tryParse(_lifeCoverCtrl.text.trim()) ?? 0;
            
            int yearsToRetirement = (60 - age).clamp(0, 60).toInt();
            double requiredTermCover = yearsToRetirement * monthlyIncome * 12;
            double gap = (requiredTermCover - currentLifeCover).clamp(0, double.infinity);
            bool isAdequate = currentLifeCover >= requiredTermCover;
            
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isAdequate ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isAdequate ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAdequate ? Icons.check_circle : Icons.warning,
                        color: isAdequate ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Term Insurance Requirement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAdequate ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have financial dependents. Term insurance is essential.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text('Required Cover: ₹${requiredTermCover.toStringAsFixed(0)}'),
                  Text('(Formula: (60-age) × monthly income × 12)'),
                  if (currentLifeCover > 0)
                    Text('Current Life Cover: ₹${currentLifeCover.toStringAsFixed(0)}'),
                  if (!isAdequate && gap > 0)
                    Text(
                      'Gap: ₹${gap.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  if (isAdequate)
                    const Text(
                      '✓ Your current cover is adequate',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            );
          }),
        _saveButton(() {
          _saveSection('family_info', {
            'spouse':
                _maritalStatus == 'Married'
                    ? _spouseNameCtrl.text.trim()
                    : null,
            'children':
                _childrenCtrls
                    .map(
                      (m) => {
                        'name': m['name']!.text.trim(),
                        'age': m['age']!.text.trim(),
                      },
                    )
                    .toList(),
            'dependents':
                _hasDependents
                    ? _dependentsCtrls
                        .map(
                          (m) => {
                            'name': m['name']!.text.trim(),
                            'relation': m['relation']!.text.trim(),
                          },
                        )
                        .toList()
                    : [],
            'has_financial_dependents': _childrenCount > 0 || (_hasDependents && _dependentsCtrls.isNotEmpty),
          });
        }),
      ],
    );
  }

  Widget _buildGoals() {
    // Calculate retirement corpus for display
    double age = double.tryParse(_ageCtrl.text.trim()) ?? 30;
    double monthlyIncome = (double.tryParse(_annualIncomeCtrl.text.trim()) ?? 0) / 12;
    double monthlyExpenses = double.tryParse(_monthlyExpensesCtrl.text.trim()) ?? 0;
    double desiredPension = double.tryParse(_desiredMonthlyPensionCtrl.text.trim()) ?? 0;
    
    int yearsToRetirement = (60 - age).clamp(0, 60).toInt();
    double standardCorpus = yearsToRetirement * monthlyIncome * 12;
    double inflationAdjustedCorpus = 0;
    if (desiredPension > 0) {
      double inflationMultiplier = 1.06; // 6% inflation
      for (int i = 0; i < yearsToRetirement; i++) {
        inflationMultiplier *= 1.06;
      }
      inflationAdjustedCorpus = desiredPension * 12 * inflationMultiplier * 25; // 25 years of retirement
    }
    
    bool pensionBelowExpenses = desiredPension > 0 && monthlyExpenses > 0 && desiredPension < monthlyExpenses;
    
    return _sectionCard(
      title: 'Goals',
      children: [
        SwitchListTile(
          title: const Text('Track Goals?'),
          value: _addGoals,
          onChanged: (v) => setState(() => _addGoals = v),
        ),
        if (_addGoals)
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _goalCtrls.add({
                      'target_amount': TextEditingController(),
                      'horizon_years': TextEditingController(),
                      'suggested_strategy': TextEditingController(),
                    });
                    _goalTypes.add(kGoalTypes.first); // Default to first goal type
                    // Initialize per-goal risk profile with defaults
                    _goalRiskTolerances.add('Medium');
                    _goalImportances.add('Important');
                    _goalFlexibilities.add('Fixed');
                    _goalBehaviors.add('Hold');
                  });
                },
                child: const Text('Add Goal'),
              ),
              for (int i = 0; i < _goalCtrls.length; i++)
                _goalTile(i, _goalCtrls[i]),
            ],
          ),
        const Divider(height: 32),
        // Retirement Planning Section
        SwitchListTile(
          title: const Text('Retirement Planning'),
          subtitle: const Text('Plan for retirement pension'),
          value: _wantsRetirementPlanning,
          onChanged: (v) => setState(() => _wantsRetirementPlanning = v),
        ),
        if (_wantsRetirementPlanning) ...[
          _textField(
            _desiredMonthlyPensionCtrl,
            'Desired Monthly Pension (₹)',
            keyboard: TextInputType.number,
          ),
          if (pensionBelowExpenses)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pension is below your current monthly expenses. Consider setting a higher amount.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Retirement Calculations',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                Text('Years to Retirement: $yearsToRetirement years'),
                Text('Standard Corpus: ₹${standardCorpus.toStringAsFixed(0)}'),
                Text('(Formula: (60-age) × monthly income × 12)'),
                if (desiredPension > 0) ...[
                  const Divider(),
                  Text('Your Pension Goal: ₹${desiredPension.toStringAsFixed(0)}/month'),
                  Text('Inflation-Adjusted Corpus: ₹${inflationAdjustedCorpus.toStringAsFixed(0)}'),
                  const Text('(Assumes 6% inflation, 25-year retirement)', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
        _saveButton(() {
          _saveSection('goals', {
            'items':
                _addGoals
                    ? List.generate(_goalCtrls.length, (i) {
                        final g = _goalCtrls[i];
                        return {
                          'name': i < _goalTypes.length ? _goalTypes[i] : '',
                          'target_amount': g['target_amount']!.text.trim(),
                          'horizon_years': g['horizon_years']!.text.trim(),
                          'suggested_strategy': g['suggested_strategy']!.text.trim(),
                          // Per-goal risk profile
                          'risk_tolerance': i < _goalRiskTolerances.length ? _goalRiskTolerances[i].toLowerCase() : 'medium',
                          'goal_importance': i < _goalImportances.length ? _goalImportances[i].toLowerCase() : 'important',
                          'goal_flexibility': i < _goalFlexibilities.length ? _goalFlexibilities[i].toLowerCase() : 'fixed',
                          'behavior': i < _goalBehaviors.length ? _goalBehaviors[i].toLowerCase() : 'hold',
                        };
                      })
                    : [],
            'wants_retirement_planning': _wantsRetirementPlanning,
            'desired_monthly_pension': _desiredMonthlyPensionCtrl.text.trim(),
          });
        }),
      ],
    );
  }


  Widget _goalTile(int i, Map<String, TextEditingController> ctrls) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _dropdown<String>(
              label: 'Goal ${i + 1} Type',
              value: i < _goalTypes.length ? _goalTypes[i] : kGoalTypes.first,
              items: kGoalTypes,
              onChanged: (v) => setState(() {
                if (i < _goalTypes.length) {
                  _goalTypes[i] = v;
                }
              }),
            ),
            _inlineRow([
              Expanded(
                child: _textField(
                  ctrls['target_amount']!,
                  'Target (₹)',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  ctrls['horizon_years']!,
                  'Horizon (yrs)',
                  keyboard: TextInputType.number,
                ),
              ),
            ]),
            _textField(
              ctrls['suggested_strategy']!,
              'Suggested Strategy (optional)',
            ),
            const Divider(height: 20),
            const Text('Goal Risk Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _dropdown<String>(
              label: 'Risk Tolerance',
              value: i < _goalRiskTolerances.length ? _goalRiskTolerances[i] : 'Medium',
              items: const ['Low', 'Medium', 'High'],
              onChanged: (v) => setState(() {
                if (i < _goalRiskTolerances.length) {
                  _goalRiskTolerances[i] = v;
                }
              }),
            ),
            _dropdown<String>(
              label: 'Goal Importance',
              value: i < _goalImportances.length ? _goalImportances[i] : 'Important',
              items: const ['Essential', 'Important', 'Lifestyle'],
              onChanged: (v) => setState(() {
                if (i < _goalImportances.length) {
                  _goalImportances[i] = v;
                }
              }),
            ),
            _dropdown<String>(
              label: 'Goal Flexibility',
              value: i < _goalFlexibilities.length ? _goalFlexibilities[i] : 'Fixed',
              items: const ['Critical', 'Fixed', 'Flexible'],
              onChanged: (v) => setState(() {
                if (i < _goalFlexibilities.length) {
                  _goalFlexibilities[i] = v;
                }
              }),
            ),
            _dropdown<String>(
              label: 'Behaviour In 15% Drop',
              value: i < _goalBehaviors.length ? _goalBehaviors[i] : 'Hold',
              items: const ['Sell', 'Reduce', 'Hold', 'Buy', 'Aggressive Buy'],
              onChanged: (v) => setState(() {
                if (i < _goalBehaviors.length) {
                  _goalBehaviors[i] = v;
                }
              }),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() {
                    _goalCtrls.removeAt(i);
                    if (i < _goalTypes.length) _goalTypes.removeAt(i);
                    if (i < _goalRiskTolerances.length) _goalRiskTolerances.removeAt(i);
                    if (i < _goalImportances.length) _goalImportances.removeAt(i);
                    if (i < _goalFlexibilities.length) _goalFlexibilities.removeAt(i);
                    if (i < _goalBehaviors.length) _goalBehaviors.removeAt(i);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildRiskProfile() {
    return _sectionCard(
      title: 'General Risk Profile',
      children: [
        _textField(
          _lossToleranceCtrl,
          'Max Short-Term Loss % You Can Tolerate',
          keyboard: TextInputType.number,
        ),
        _dropdown<String>(
          label: 'Behaviour In 15% Drop',
          value: _behavior,
          items: const ['Sell', 'Reduce', 'Hold', 'Buy', 'Aggressive Buy'],
          onChanged: (v) => setState(() => _behavior = v),
        ),
        _textField(
          _emergencyFundMonthsCtrl,
          'Emergency Fund (Months of Expenses)',
          keyboard: TextInputType.number,
        ),
        _textField(
          _equityAllocationCtrl,
          'Current Equity Allocation % (optional override)',
          keyboard: TextInputType.number,
        ),
        _saveButton(() {
          if (_loading) return;
          String lt = _lossToleranceCtrl.text.trim();
          String phY = _primaryHorizonYearsCtrl.text.trim();
          String efm = _emergencyFundMonthsCtrl.text.trim();
          String eq = _equityAllocationCtrl.text.trim();

          double? parseNum(String s) => s.isEmpty ? null : double.tryParse(s);

          double? ltVal = parseNum(lt);
          if (lt.isNotEmpty && (ltVal == null || ltVal < 0 || ltVal > 100)) {
            setState(() {
              _statusMessage =
                  'Validation: Max Short-Term Loss % must be between 0 and 100.';
            });
            return;
          }

          double? phVal = parseNum(phY);
          if (phY.isNotEmpty && (phVal == null || phVal < 0 || phVal > 100)) {
            setState(() {
              _statusMessage =
                  'Validation: Primary Horizon (Years) must be 0–100.';
            });
            return;
          }

          double? efmVal = parseNum(efm);
          if (efm.isNotEmpty &&
              (efmVal == null || efmVal < 0 || efmVal > 240)) {
            setState(() {
              _statusMessage =
                  'Validation: Emergency Fund Months must be 0–240.';
            });
            return;
          }

          double? eqVal = parseNum(eq);
          if (eq.isNotEmpty && (eqVal == null || eqVal < 0 || eqVal > 100)) {
            setState(() {
              _statusMessage = 'Validation: Equity Allocation % must be 0–100.';
            });
            return;
          }

          _saveSection('risk_profile', {
            'tolerance': _riskTolerance.toLowerCase(),
            'primary_horizon': _primaryHorizon.toLowerCase(),
            'primary_horizon_years': phY,
            'loss_tolerance_percent': lt,
            'goal_importance': _goalImportance.toLowerCase(),
            'goal_flexibility': _goalFlexibility.toLowerCase(),
            'behavior': _behavior.toLowerCase(),
            'income_stability': _incomeStability.toLowerCase(),
            'emergency_fund_months': efm,
            'equity_allocation_percent': eq,
          });
        }),
      ],
    );
  }


  Widget _buildInsurance() {
    final hasInsurancePrefill = _prefilledFields.intersection({'life_cover', 'health_cover'}).isNotEmpty;
    return _sectionCard(
      title: 'Insurance Coverage',
      showPrefillWarning: hasInsurancePrefill,
      children: [
        _textField(
          _lifeCoverCtrl,
          'Term Life Cover (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('life_cover'),
        ),
        CheckboxListTile(
          title: const Text('I already have term life insurance'),
          subtitle: const Text('Check if you have adequate life cover'),
          value: _hasTermInsuranceConfirmed,
          onChanged: (v) => setState(() => _hasTermInsuranceConfirmed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        _textField(
          _healthCoverCtrl,
          'Health Cover (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('health_cover'),
        ),
        CheckboxListTile(
          title: const Text('I already have health insurance'),
          subtitle: const Text('Check if you have adequate health cover'),
          value: _hasHealthInsuranceConfirmed,
          onChanged: (v) => setState(() => _hasHealthInsuranceConfirmed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        _saveButton(() {
          _saveSection('insurance', {
            'life_cover': _lifeCoverCtrl.text.trim(),
            'health_cover': _healthCoverCtrl.text.trim(),
            'has_term_insurance_confirmed': _hasTermInsuranceConfirmed,
            'has_health_insurance_confirmed': _hasHealthInsuranceConfirmed,
          });
        }),
      ],
    );
  }


  Widget _buildLifestyle() {
    final hasLifestylePrefill = _prefilledFields.intersection({'annual_income', 'monthly_expenses', 'monthly_emi', 'available_savings', 'savings_percent', 'alloc_equity', 'alloc_debt', 'alloc_gold', 'alloc_realEstate', 'alloc_insuranceLinked', 'alloc_cash'}).isNotEmpty;
    return _sectionCard(
      title: 'Lifestyle & Allocation',
      showPrefillWarning: hasLifestylePrefill,
      children: [
        _textField(
          _annualIncomeCtrl,
          'Annual Income (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('annual_income'),
        ),
        _textField(
          _monthlyExpensesCtrl,
          'Monthly Expenses (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('monthly_expenses'),
        ),
        _textField(
          _monthlyEmiCtrl,
          'Monthly EMI (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('monthly_emi'),
        ),
        _textField(
          _emergencyFundCtrl,
          'Emergency Fund (₹)',
          keyboard: TextInputType.number,
        ),
        _textField(
          _availableSavingsCtrl,
          'Available Savings for Investments/Insurance (₹)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('available_savings'),
        ),
        _textField(
          _savingsPercentCtrl,
          'Savings % (if known)',
          keyboard: TextInputType.number,
          isPrefilled: _prefilledFields.contains('savings_percent'),
        ),
        _dropdown<String>(
          label: 'Savings Band',
          value: _savingsBand.isEmpty ? 'Unknown' : _savingsBand,
          items: const ['Unknown', '<10%', '10-20%', '20-30%', '>30%'],
          onChanged:
              (v) => setState(() {
                _savingsBand = v == 'Unknown' ? '' : v;
              }),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in ['MF', 'FD', 'Gold', 'Stocks', 'RealEstate'])
              FilterChip(
                label: Text(p),
                selected: _currentProducts.contains(p),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _currentProducts.add(p);
                    } else {
                      _currentProducts.remove(p);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Allocation % (optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        _allocationRow('Equity', _allocationCtrls['equity']!, isPrefilled: _prefilledFields.contains('alloc_equity')),
        _allocationRow('Debt', _allocationCtrls['debt']!, isPrefilled: _prefilledFields.contains('alloc_debt')),
        _allocationRow('Gold', _allocationCtrls['gold']!, isPrefilled: _prefilledFields.contains('alloc_gold')),
        _allocationRow('Real Estate', _allocationCtrls['realEstate']!, isPrefilled: _prefilledFields.contains('alloc_realEstate')),
        _allocationRow(
          'Insurance Linked',
          _allocationCtrls['insuranceLinked']!,
          isPrefilled: _prefilledFields.contains('alloc_insuranceLinked'),
        ),
        _allocationRow('Cash', _allocationCtrls['cash']!, isPrefilled: _prefilledFields.contains('alloc_cash')),
        _saveButton(() {
          _saveSection('lifestyle', {
            'annual_income': _annualIncomeCtrl.text.trim(),
            'monthly_expenses': _monthlyExpensesCtrl.text.trim(),
            'monthly_emi': _monthlyEmiCtrl.text.trim(),
            'emergency_fund': _emergencyFundCtrl.text.trim(),
            'available_savings': _availableSavingsCtrl.text.trim(),
            'savings_percent': _savingsPercentCtrl.text.trim(),
            'savings_band': _savingsBand,
            'products': _currentProducts,
            'allocation': {
              for (final e in _allocationCtrls.entries)
                if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
            },
          });
        }),
      ],
    );
  }

  Widget _buildEstate() {
    return _sectionCard(
      title: 'Estate Planning',
      children: [
        _dropdown<String>(
          label: 'Will Status',
          value: _willStatus,
          items: const ['Yes', 'No', 'Not Applicable'],
          onChanged: (v) => setState(() => _willStatus = v),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nominee Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _nomineeCtrls.add({
                    'name': TextEditingController(),
                    'relation': TextEditingController(),
                    'allocation': TextEditingController(),
                  });
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Nominee'),
            ),
          ],
        ),
        if (_nomineeCtrls.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No nominees added. Click "Add Nominee" to add nominee details.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        for (int i = 0; i < _nomineeCtrls.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _textField(
                    _nomineeCtrls[i]['name']!,
                    'Nominee ${i + 1} Name',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _nomineeCtrls[i]['relation']!,
                    'Relation',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _nomineeCtrls[i]['allocation']!,
                    'Share %',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _nomineeCtrls.removeAt(i);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        _saveButton(() {
          _saveSection('estate', {
            'will_status': _willStatus,
            'nominees': _nomineeCtrls
                .map((n) => {
                      'name': n['name']!.text.trim(),
                      'relation': n['relation']!.text.trim(),
                      'allocation_percent': n['allocation']!.text.trim(),
                    })
                .toList(),
          });
        }),
      ],
    );
  }

  // UI Helpers

  Widget _sectionCard({required String title, required List<Widget> children, bool showPrefillWarning = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth < 600 ? 16.0 : 32.0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          AppTheme.goldAccentBar(width: 60, height: 2),
          if (showPrefillWarning) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x15FF0000),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x30FF0000), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The highlighted values below were auto-calculated from your documents. Please double-check and enter the correct amount if needed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB71C1C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool isPrefilled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isPrefilled ? const Color(0x14FF0000) : Colors.white,
          enabledBorder: isPrefilled
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: const BorderSide(color: Color(0x55FF0000), width: 1),
                )
              : null,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items:
                items
                    .map(
                      (e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(e.toString()),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _numberStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int max = 10,
  }) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text(value.toString()),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _inlineRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: children),
    );
  }

  Widget _allocationRow(String label, TextEditingController c, {bool isPrefilled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
              child: Text(label),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '%',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: isPrefilled ? const Color(0x14FF0000) : Colors.white,
                enabledBorder: isPrefilled
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: const BorderSide(color: Color(0x55FF0000), width: 1),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const FittedBox(child: Text('Save Section')),
        ),
      ),
    );
  }

  List<Widget> _steps() {
    return [
      _buildPersonalInfo(),
      _buildFamilyInfo(),
      _buildGoals(),
      _buildRiskProfile(),
      _buildInsurance(),
      _buildLifestyle(),
      _buildEstate(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      body:
          _qid == null
              ? _buildIntroScreen(context)
              : Stack(
                children: [
                  // Main questionnaire content
                  AbsorbPointer(
                    absorbing: _isGeneratingReport,
                    child: Opacity(
                      opacity: _isGeneratingReport ? 0.3 : 1.0,
                      child: Column(
                        children: [
                          _progressIndicator(steps.length),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final hPad = constraints.maxWidth < 600 ? 16.0 : 40.0;
                                return SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
                                  child: steps[_stepIndex],
                                );
                              },
                            ),
                          ),
                          _navigationBar(steps.length),
                          if (_stepIndex == steps.length - 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: _planUrl != null
                                // Report is ready - show Open PDF + Edit option
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _openPlan,
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text('Open PDF'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.successGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _stepIndex = 0;
                                            _planUrl = null;
                                            _statusMessage = '';
                                          });
                                        },
                                        icon: const Icon(Icons.edit_note),
                                        label: const Text('Edit & Regenerate'),
                                      ),
                                    ],
                                  )
                                // No report yet - show generate button
                                : Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: (_loading || _isGeneratingReport) ? null : () async {
                                            await _autoSaveCurrentSection();
                                            await _generateReport();
                                          },
                                          icon: const Icon(Icons.picture_as_pdf),
                                          label: const FittedBox(child: Text('Submit and Generate Report')),
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          if (_statusMessage.isNotEmpty && !_isGeneratingReport)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _statusMessage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                                      ? AppTheme.errorRed
                                      : AppTheme.successGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Full-screen loading overlay during report generation
                  if (_isGeneratingReport)
                    Container(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.85),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Generating Your Financial Report',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Our AI is analyzing your data and creating\npersonalized recommendations...',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: 260,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: const LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor: Colors.white24,
                                  color: AppTheme.accentGold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This may take up to a minute',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _buildIntroScreen(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryNavy, Color(0xFF0D2136)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.goldAccentBar(width: 80, height: 3),
              const SizedBox(height: 40),
              Text(
                'Financial',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 56,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Questionnaire',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppTheme.accentGold,
                  fontSize: 56,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 600,
                child: Text(
                  'Complete this comprehensive questionnaire to help us understand your financial situation, goals, and risk profile. The information you provide will be used to generate a personalized financial plan.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 60),
              if (_loading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: AppTheme.accentGold,
                    strokeWidth: 3,
                  ),
                )
              else
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _startQuestionnaire,
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: const Text('Begin Questionnaire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressIndicator(int total) {
    final progress = (_stepIndex + 1) / total;
    final percentage = (progress * 100).toInt();
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 600 ? 16.0 : 40.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.accentGold,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_stepIndex + 1} of $total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationBar(int total) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 600 ? 16.0 : 40.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_stepIndex > 0)
            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : () async {
                        await _autoSaveCurrentSection();
                        setState(() {
                          _stepIndex--;
                        });
                      },
              child: const FittedBox(child: Text('Back')),
            ),
          const Spacer(),
          Text('Step ${_stepIndex + 1} / $total'),
          const Spacer(),
          if (_stepIndex < total - 1)
            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : () async {
                        await _autoSaveCurrentSection();
                        setState(() {
                          _stepIndex++;
                        });
                      },
              child: const FittedBox(child: Text('Next')),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _panCtrl.dispose();
    _dobCtrl.dispose();
    _contactCtrl.dispose();
    _spouseNameCtrl.dispose();
    for (final m in _childrenCtrls) {
      m['name']!.dispose();
      m['age']!.dispose();
    }
    for (final m in _dependentsCtrls) {
      m['name']!.dispose();
      m['relation']!.dispose();
    }
    for (final m in _goalCtrls) {
      m['target_amount']!.dispose();
      m['horizon_years']!.dispose();
      m['suggested_strategy']!.dispose();
    }
    _lifeCoverCtrl.dispose();
    _healthCoverCtrl.dispose();
    _annualIncomeCtrl.dispose();
    _monthlyExpensesCtrl.dispose();
    _monthlyEmiCtrl.dispose();
    _emergencyFundCtrl.dispose();
    _savingsPercentCtrl.dispose();
    for (final c in _allocationCtrls.values) {
      c.dispose();
    }
    for (final m in _nomineeCtrls) {
      m['name']!.dispose();
      m['relation']!.dispose();
      m['allocation']!.dispose();
    }
    _lossToleranceCtrl.dispose();
    _primaryHorizonYearsCtrl.dispose();
    _emergencyFundMonthsCtrl.dispose();
    _equityAllocationCtrl.dispose();
    super.dispose();
  }
}
