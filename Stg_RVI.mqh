/**
 * @file
 * Implements RVI strategy based on the Relative Vigor Index indicator.
 */

// User input params.
INPUT string __RVI_Parameters__ = "-- RVI strategy params --";  // >>> RVI <<<
INPUT float RVI_LotSize = 0;                                    // Lot size
INPUT int RVI_SignalOpenMethod = 2;                             // Signal open method (-127-127)
INPUT float RVI_SignalOpenLevel = 0.0f;                         // Signal open level
INPUT int RVI_SignalOpenFilterMethod = 32;                      // Signal open filter method
INPUT int RVI_SignalOpenBoostMethod = 0;                        // Signal open boost method
INPUT int RVI_SignalCloseMethod = 2;                            // Signal close method (-127-127)
INPUT float RVI_SignalCloseLevel = 0.0f;                        // Signal close level
INPUT int RVI_PriceStopMethod = 1;                              // Price stop method
INPUT float RVI_PriceStopLevel = 0;                             // Price stop level
INPUT int RVI_TickFilterMethod = 1;                             // Tick filter method
INPUT float RVI_MaxSpread = 4.0;                                // Max spread to trade (pips)
INPUT short RVI_Shift = 2;                                      // Shift
INPUT int RVI_OrderCloseTime = -20;                             // Order close time in mins (>0) or bars (<0)
INPUT string __RVI_Indi_RVI_Parameters__ =
    "-- RVI strategy: RVI indicator params --";  // >>> RVI strategy: RVI indicator <<<
INPUT unsigned int RVI_Indi_RVI_Period = 10;     // Averaging period
INPUT int RVI_Indi_RVI_Shift = 0;                // Shift

// Structs.

// Defines struct with default user indicator values.
struct Indi_RVI_Params_Defaults : RVIParams {
  Indi_RVI_Params_Defaults() : RVIParams(::RVI_Indi_RVI_Period, ::RVI_Indi_RVI_Shift) {}
} indi_rvi_defaults;

// Defines struct with default user strategy values.
struct Stg_RVI_Params_Defaults : StgParams {
  Stg_RVI_Params_Defaults()
      : StgParams(::RVI_SignalOpenMethod, ::RVI_SignalOpenFilterMethod, ::RVI_SignalOpenLevel,
                  ::RVI_SignalOpenBoostMethod, ::RVI_SignalCloseMethod, ::RVI_SignalCloseLevel, ::RVI_PriceStopMethod,
                  ::RVI_PriceStopLevel, ::RVI_TickFilterMethod, ::RVI_MaxSpread, ::RVI_Shift, ::RVI_OrderCloseTime) {}
} stg_rvi_defaults;

// Struct to define strategy parameters to override.
struct Stg_RVI_Params : StgParams {
  RVIParams iparams;
  StgParams sparams;

  // Struct constructors.
  Stg_RVI_Params(RVIParams &_iparams, StgParams &_sparams)
      : iparams(indi_rvi_defaults, _iparams.tf.GetTf()), sparams(stg_rvi_defaults) {
    iparams = _iparams;
    sparams = _sparams;
  }
};

// Loads pair specific param values.
#include "config/EURUSD_H1.h"
#include "config/EURUSD_H4.h"
#include "config/EURUSD_H8.h"
#include "config/EURUSD_M1.h"
#include "config/EURUSD_M15.h"
#include "config/EURUSD_M30.h"
#include "config/EURUSD_M5.h"

class Stg_RVI : public Strategy {
 public:
  Stg_RVI(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_RVI *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    RVIParams _indi_params(indi_rvi_defaults, _tf);
    StgParams _stg_params(stg_rvi_defaults);
#ifdef __config__
    SetParamsByTf<RVIParams>(_indi_params, _tf, indi_rvi_m1, indi_rvi_m5, indi_rvi_m15, indi_rvi_m30, indi_rvi_h1,
                             indi_rvi_h4, indi_rvi_h8);
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_rvi_m1, stg_rvi_m5, stg_rvi_m15, stg_rvi_m30, stg_rvi_h1, stg_rvi_h4,
                             stg_rvi_h8);
#endif
    // Initialize indicator.
    RVIParams rvi_params(_indi_params);
    _stg_params.SetIndicator(new Indi_RVI(_indi_params));
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams(_magic_no, _log_level);
    Strategy *_strat = new Stg_RVI(_stg_params, _tparams, _cparams, "RVI");
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_RVI *_indi = GetIndicator();
    bool _is_valid = _indi[_shift].IsValid() && _indi[_shift + 1].IsValid() && _indi[_shift + 2].IsValid();
    bool _result = _is_valid;
    if (_is_valid) {
      IndicatorSignal _signals = _indi.GetSignals(4, _shift, LINE_MAIN, LINE_SIGNAL);
      switch (_cmd) {
        case ORDER_TYPE_BUY:
          // Buy: main line (green) crosses signal (red) upwards.
          _result &= _indi[_shift][0] < _level;
          _result &= _indi.IsIncreasing(2, LINE_SIGNAL, _shift);
          _result &= _indi[_shift][(int)LINE_SIGNAL] > _indi[_shift][(int)LINE_MAIN];
          _result &= _indi.IsIncByPct(_level, 0, 0, 2);
          _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
          break;
        case ORDER_TYPE_SELL:
          // Sell: main line (green) crosses signal (red) downwards.
          _result &= _indi[_shift][0] > _level;
          _result &= _indi.IsDecreasing(2, LINE_SIGNAL, _shift);
          _result &= _indi[_shift][(int)LINE_SIGNAL] < _indi[_shift][(int)LINE_MAIN];
          _result &= _indi.IsDecByPct(-_level, 0, 0, 2);
          _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
          break;
      }
    }
    return _result;
  }
};
