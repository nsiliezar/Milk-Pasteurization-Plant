FUNCTION_BLOCK ScaleAnalog
  VAR_INPUT
    RawValue : INT;
    RangeMax : REAL;
  END_VAR
  VAR_OUTPUT
    ScaledValue : REAL;
    RawReal : REAL;
  END_VAR

  RawReal := INT_TO_REAL(RawValue);
  ScaledValue := (RawReal / 32767.0) * RangeMax;
END_FUNCTION_BLOCK

FUNCTION_BLOCK ProcessControl
  VAR_INPUT
    Enable : BOOL := TRUE;
    PreHeatTemp : INT;
    T01_Temp : INT;
    T02_Temp : INT;
    BoosterPump : BOOL;
  END_VAR
  VAR_OUTPUT
    HotWaterValve : INT;
    AlarmLamp : BOOL;
  END_VAR
  VAR
    fbScalePreHeat : ScaleAnalog;
    fbScaleT01Temp : ScaleAnalog;
    fbScaleT02Temp : ScaleAnalog;
    PreHeat_Temp_C : REAL;
    T01_Temp_C : REAL;
    T02_Temp_C : REAL;
    PREHEAT_SP : REAL := 40.0;
    PREHEAT_HYST : REAL := 1.0;
    STORAGE_TEMP_HI : REAL := 8.0;
    Alarm_PreHeatHigh : BOOL;
    Alarm_PreHeatLow : BOOL;
    Alarm_T01_TempHigh : BOOL;
    Alarm_T02_TempHigh : BOOL;
    tPreHeatTimeout : TON;
    PREHEAT_TIMEOUT : TIME := T#99h;
  END_VAR
  VAR_INPUT
    PastTempIn : INT;
    PastTempOut : INT;
  END_VAR
  VAR
    fbScalePastIn : ScaleAnalog;
    fbScalePastOut : ScaleAnalog;
    PastIn_Temp_C : REAL;
    PastOut_Temp_C : REAL;
    PAST_SP : REAL := 72.0;
    PAST_HYST : REAL := 0.5;
  END_VAR
  VAR_OUTPUT
    HoldTimeMet : BOOL;
  END_VAR
  VAR
    tHoldTimer : TON;
    HOLD_TIME : TIME := T#15s;
    Alarm_PastTempLow : BOOL;
    Alarm_DivertFault : BOOL;
  END_VAR
  VAR_OUTPUT
    DivertValve : BOOL;
    HeatingValve : INT;
  END_VAR
  VAR_INPUT
    DivertValve_FB : BOOL;
    CoolTempOut : INT;
    T03_Temp : INT;
  END_VAR
  VAR
    fbScaleCoolOut : ScaleAnalog;
    fbScaleT03Temp : ScaleAnalog;
    CoolOut_Temp_C : REAL;
    T03_Temp_C : REAL;
    COOL_SP : REAL := 4.0;
    COOL_HYST : REAL := 0.5;
    T03_TEMP_MAX : REAL := 6.0;
    Alarm_CoolTempHigh : BOOL;
    Alarm_T03_TempHigh : BOOL;
  END_VAR
  VAR_OUTPUT
    ChillWaterValve : INT;
    CoolingOK : BOOL;
  END_VAR
  VAR_INPUT
    CIP_Start : BOOL;
    CIP_Temp : INT;
  END_VAR
  VAR
    fbScaleCIPTemp : ScaleAnalog;
    CIP_Temp_C : REAL;
    CIP_Step : INT := 0;
    tCIP_Step : TON;
    CIP_RINSE_TIME : TIME := T#5m;
    CIP_CAUSTIC_TIME : TIME := T#15m;
    CIP_ACID_TIME : TIME := T#10m;
    Alarm_CIP_Temp : BOOL;
  END_VAR
  VAR_OUTPUT
    CIP_Active : BOOL;
    CIP_WaterValve : BOOL;
    CIP_CausticValve : BOOL;
    CIP_AcidValve : BOOL;
    CIP_ReturnPump : BOOL;
  END_VAR
  VAR_INPUT
    PlantStart : BOOL;
    PlantStop : BOOL;
    AlarmReset : BOOL;
  END_VAR
  VAR_OUTPUT
    PlantState : INT;
  END_VAR
  VAR_INPUT
    tStartup : TON;
    STARTUP_TIME : TIME := T#10s;
    AnyAlarm : BOOL;
    BalanceLowLevel : BOOL;
  END_VAR
  VAR_OUTPUT
    RunLamp : BOOL;
    PlantRunning : BOOL;
    AlarmActive : BOOL;
    AlarmCode : INT;
  END_VAR
  VAR
    AlarmLatched : BOOL;
  END_VAR


  fbScalePreHeat(
      RawValue := PreHeatTemp,
      RangeMax := 100.0
  );
  PreHeat_Temp_C := fbScalePreHeat.ScaledValue;

  fbScaleT01Temp(
      RawValue := T01_Temp,
      RangeMax := 100.0
  );
  T01_Temp_C := fbScaleT01Temp.ScaledValue;

  fbScaleT02Temp(
      RawValue := T02_Temp,
      RangeMax := 100.0
  );
  T02_Temp_C := fbScaleT02Temp.ScaledValue;

  IF Enable THEN

      IF BoosterPump THEN
          IF PreHeat_Temp_C < (PREHEAT_SP - PREHEAT_HYST) THEN
              HotWaterValve := 32767;
          ELSIF PreHeat_Temp_C > (PREHEAT_SP + PREHEAT_HYST) THEN
              HotWaterValve := 0;
          END_IF;
      ELSE
          HotWaterValve := 0;
      END_IF;

      IF T01_Temp_C > STORAGE_TEMP_HI THEN
          Alarm_T01_TempHigh := TRUE;
      ELSE
          Alarm_T01_TempHigh := FALSE;
      END_IF;

      IF T02_Temp_C > STORAGE_TEMP_HI THEN
          Alarm_T02_TempHigh := TRUE;
      ELSE
          Alarm_T02_TempHigh := FALSE;
      END_IF;

      IF PreHeat_Temp_C > 50.0 THEN
          Alarm_PreHeatHigh := TRUE;
      ELSE
          Alarm_PreHeatHigh := FALSE;
      END_IF;

      tPreHeatTimeout(
          IN := BoosterPump,
          PT := PREHEAT_TIMEOUT
      );
      Alarm_PreHeatLow := tPreHeatTimeout.Q;

      IF Alarm_PreHeatHigh
          OR Alarm_PreHeatLow
          OR Alarm_T01_TempHigh
          OR Alarm_T02_TempHigh
      THEN
          AlarmLamp := TRUE;
      ELSE
          AlarmLamp := FALSE;
      END_IF;

  END_IF;

  (*added code*)

  (* === SECTION 4: PASTEURIZER CONTROL === *)

  fbScalePastIn(
      RawValue := PastTempIn,
      RangeMax := 100.0
  );
  PastIn_Temp_C := fbScalePastIn.ScaledValue;

  fbScalePastOut(
      RawValue := PastTempOut,
      RangeMax := 100.0
  );
  PastOut_Temp_C := fbScalePastOut.ScaledValue;

  (* Hold timer — only runs when BOTH sensors confirm 72°C.
     Resets immediately if either sensor drops below setpoint. *)
  tHoldTimer(
      IN := (PastIn_Temp_C >= PAST_SP) AND
            (PastOut_Temp_C >= PAST_SP),
      PT := HOLD_TIME
  );
  HoldTimeMet := tHoldTimer.Q;

  (* Heating valve control — bang-bang like pre-heat.
     Only heats when booster pump is running. *)
  IF BoosterPump THEN
      IF PastOut_Temp_C < (PAST_SP - PAST_HYST) THEN
          HeatingValve := 32767;
      ELSIF PastOut_Temp_C > (PAST_SP + PAST_HYST) THEN
          HeatingValve := 0;
      END_IF;
  ELSE
      HeatingValve := 0;
  END_IF;

  (* Pasteurizer alarms *)
  IF BoosterPump AND (PastOut_Temp_C < (PAST_SP - PAST_HYST)) THEN
      Alarm_PastTempLow := TRUE;
  ELSE
      Alarm_PastTempLow := FALSE;
  END_IF;

  IF DivertValve AND NOT(DivertValve_FB) THEN
      Alarm_DivertFault := TRUE;
  ELSE
      Alarm_DivertFault := FALSE;
  END_IF;

  IF Alarm_PastTempLow OR Alarm_DivertFault THEN
      AlarmLamp := TRUE;
  END_IF;

  (* added code *)

  (* === SECTION 5: COOLING CONTROL === *)

  fbScaleCoolOut(
      RawValue := CoolTempOut,
      RangeMax := 20.0
  );
  CoolOut_Temp_C := fbScaleCoolOut.ScaledValue;

  fbScaleT03Temp(
      RawValue := T03_Temp,
      RangeMax := 20.0
  );
  T03_Temp_C := fbScaleT03Temp.ScaledValue;

  (* Chilled water valve control.
     Only runs when divert valve is open — milk flowing forward. *)
  IF DivertValve THEN
      IF CoolOut_Temp_C > (COOL_SP + COOL_HYST) THEN
          ChillWaterValve := 32767;
      ELSIF CoolOut_Temp_C < (COOL_SP - COOL_HYST) THEN
          ChillWaterValve := 0;
      END_IF;
  ELSE
      ChillWaterValve := 0;
  END_IF;

  (* CoolingOK flag — milk is cold enough to enter storage.
     Both cooler outlet AND storage tank temp must be acceptable. *)
  IF (CoolOut_Temp_C <= (COOL_SP + COOL_HYST)) AND
     (T03_Temp_C <= T03_TEMP_MAX) THEN
      CoolingOK := TRUE;
  ELSE
      CoolingOK := FALSE;
  END_IF;

  (* Cooling alarms *)
  IF DivertValve AND (CoolOut_Temp_C > (COOL_SP + COOL_HYST + 2.0)) THEN
      Alarm_CoolTempHigh := TRUE;
  ELSE
      Alarm_CoolTempHigh := FALSE;
  END_IF;

  IF T03_Temp_C > T03_TEMP_MAX THEN
      Alarm_T03_TempHigh := TRUE;
  ELSE
      Alarm_T03_TempHigh := FALSE;
  END_IF;

  IF Alarm_CoolTempHigh OR Alarm_T03_TempHigh THEN
      AlarmLamp := TRUE;
  END_IF;

  (* Added coded*)

  (* === SECTION 6: CIP SEQUENCE === *)

  fbScaleCIPTemp(
      RawValue := CIP_Temp,
      RangeMax := 100.0
  );
  CIP_Temp_C := fbScaleCIPTemp.ScaledValue;

  (* CIP state machine — CASE on CIP_Step
     0 = idle
     1 = water rinse
     2 = caustic wash
     3 = acid rinse
     4 = final rinse
     5 = complete *)

  CASE CIP_Step OF

      0: (* Idle — waiting for start *)
          CIP_Active      := FALSE;
          CIP_WaterValve  := FALSE;
          CIP_CausticValve:= FALSE;
          CIP_AcidValve   := FALSE;
          CIP_ReturnPump  := FALSE;
          tCIP_Step(IN := FALSE, PT := T#1s);
          IF CIP_Start AND NOT(DivertValve) THEN
              CIP_Step := 1;
          END_IF;

      1: (* Step 1 — fresh water rinse *)
          CIP_Active      := TRUE;
          CIP_WaterValve  := TRUE;
          CIP_CausticValve:= FALSE;
          CIP_AcidValve   := FALSE;
          CIP_ReturnPump  := TRUE;
          tCIP_Step(IN := TRUE, PT := CIP_RINSE_TIME);
          IF tCIP_Step.Q THEN
              tCIP_Step(IN := FALSE, PT := T#1s);
              CIP_Step := 2;
          END_IF;

      2: (* Step 2 — caustic wash *)
          CIP_Active      := TRUE;
          CIP_WaterValve  := FALSE;
          CIP_CausticValve:= TRUE;
          CIP_AcidValve   := FALSE;
          CIP_ReturnPump  := TRUE;
          tCIP_Step(IN := TRUE, PT := CIP_CAUSTIC_TIME);
          IF tCIP_Step.Q THEN
              tCIP_Step(IN := FALSE, PT := T#1s);
              CIP_Step := 3;
          END_IF;

      3: (* Step 3 — acid rinse *)
          CIP_Active      := TRUE;
          CIP_WaterValve  := FALSE;
          CIP_CausticValve:= FALSE;
          CIP_AcidValve   := TRUE;
          CIP_ReturnPump  := TRUE;
          tCIP_Step(IN := TRUE, PT := CIP_ACID_TIME);
          IF tCIP_Step.Q THEN
              tCIP_Step(IN := FALSE, PT := T#1s);
              CIP_Step := 4;
          END_IF;

      4: (* Step 4 — final water rinse *)
          CIP_Active      := TRUE;
          CIP_WaterValve  := TRUE;
          CIP_CausticValve:= FALSE;
          CIP_AcidValve   := FALSE;
          CIP_ReturnPump  := TRUE;
          tCIP_Step(IN := TRUE, PT := CIP_RINSE_TIME);
          IF tCIP_Step.Q THEN
              tCIP_Step(IN := FALSE, PT := T#1s);
              CIP_Step := 5;
          END_IF;

      5: (* Complete — reset *)
          CIP_Active      := FALSE;
          CIP_WaterValve  := FALSE;
          CIP_CausticValve:= FALSE;
          CIP_AcidValve   := FALSE;
          CIP_ReturnPump  := FALSE;
          CIP_Step        := 0;

  END_CASE;

  (* CIP temperature alarm —
     caustic wash should be above 70°C *)
  IF (CIP_Step = 2) AND (CIP_Temp_C < 70.0) THEN
      Alarm_CIP_Temp := TRUE;
  ELSE
      Alarm_CIP_Temp := FALSE;
  END_IF;

  IF Alarm_CIP_Temp THEN
      AlarmLamp := TRUE;
  END_IF;

  (* === SECTION 7: PLANT STATE MACHINE === *)

  AnyAlarm := Alarm_PreHeatHigh
      OR Alarm_PreHeatLow
      OR Alarm_T01_TempHigh
      OR Alarm_T02_TempHigh
      OR Alarm_PastTempLow
      OR Alarm_DivertFault
      OR Alarm_CoolTempHigh
      OR Alarm_T03_TempHigh
      OR Alarm_CIP_Temp;

  IF PlantState = 2 THEN
      PlantRunning := TRUE;
  ELSE
      PlantRunning := FALSE;
  END_IF;

  CASE PlantState OF

      0:
          RunLamp := FALSE;
          PlantRunning := FALSE;
          IF PlantStart AND NOT(CIP_Active) AND NOT(AnyAlarm) THEN
              PlantState := 1;
          END_IF;
          IF CIP_Start THEN
              PlantState := 5;
          END_IF;

      1:
          RunLamp := FALSE;
          tStartup(
              IN := (PreHeat_Temp_C >= (PREHEAT_SP - PREHEAT_HYST))
                    AND NOT(BalanceLowLevel),
              PT := STARTUP_TIME
          );
          IF tStartup.Q THEN
              PlantState := 2;
          END_IF;
          IF PlantStop OR AnyAlarm THEN
              PlantState := 0;
          END_IF;

      2:
          RunLamp := TRUE;
          PlantRunning := TRUE;
          IF PlantStop THEN
              PlantState := 3;
          END_IF;
          IF AnyAlarm THEN
              PlantState := 4;
          END_IF;
          IF CIP_Start THEN
              PlantState := 5;
          END_IF;

      3:
          RunLamp := FALSE;
          PlantRunning := FALSE;
          IF NOT(BoosterPump) THEN
              PlantState := 0;
          END_IF;

      4:
          RunLamp := FALSE;
          PlantRunning := FALSE;
          AlarmLamp := TRUE;
          IF AlarmReset AND NOT(AnyAlarm) THEN
              AlarmLamp := FALSE;
              PlantState := 0;
          END_IF;

      5:
          RunLamp := FALSE;
          PlantRunning := FALSE;
          IF NOT(CIP_Active) THEN
              PlantState := 0;
          END_IF;
          IF AnyAlarm THEN
              PlantState := 4;
          END_IF;

  END_CASE;

  (*added code*)
  (* === SECTION 8: ALARM LATCHING & CODES === *)



  (* Alarm codes — operator sees a number on HMI

     telling them exactly what went wrong:

     0  = no alarm

     1  = pre-heat over temperature

     2  = pre-heat timeout (not reaching setpoint)

     3  = T01 raw milk too warm

     4  = T02 raw milk too warm

     5  = pasteurizer temperature low

     6  = divert valve fault

     7  = cooling temperature high

     8  = T03 storage temperature high

     9  = CIP temperature low                    *)



  IF Alarm_PreHeatHigh THEN

      AlarmCode := 1;

  ELSIF Alarm_PreHeatLow THEN

      AlarmCode := 2;

  ELSIF Alarm_T01_TempHigh THEN

      AlarmCode := 3;

  ELSIF Alarm_T02_TempHigh THEN

      AlarmCode := 4;

  ELSIF Alarm_PastTempLow THEN

      AlarmCode := 5;

  ELSIF Alarm_DivertFault THEN

      AlarmCode := 6;

  ELSIF Alarm_CoolTempHigh THEN

      AlarmCode := 7;

  ELSIF Alarm_T03_TempHigh THEN

      AlarmCode := 8;

  ELSIF Alarm_CIP_Temp THEN

      AlarmCode := 9;

  ELSE

      AlarmCode := 0;

  END_IF;



  (* Alarm latching — once an alarm fires it stays

     active until operator presses AlarmReset AND

     the condition has actually cleared.           *)

  IF AnyAlarm THEN

      AlarmLatched := TRUE;

  END_IF;



  IF AlarmReset AND NOT(AnyAlarm) THEN

      AlarmLatched := FALSE;

      AlarmLamp := FALSE;

  END_IF;



  (* AlarmActive is the latched output — this is

     what Node-RED reads to show alarm status     *)

  AlarmActive := AlarmLatched;
END_FUNCTION_BLOCK

PROGRAM TankLevel
  VAR
    TankerArrival AT %QX0.0 : BOOL;
    InletValveOpen AT %QX0.1 : BOOL;
    InletValveClosed AT %QX0.2 : BOOL;
    ReceptionFT AT %QW0 : INT;
    InletValve AT %QX1.0 : BOOL;
    ReceptionPump AT %QX1.1 : BOOL;
    Pump AT %QX0.3 : BOOL;
    LowLevel AT %QX0.4 : BOOL;
    HighLevel AT %QX0.5 : BOOL;
    Start AT %QX0.6 : BOOL;
    Stop AT %QX0.7 : BOOL;
    T02_LowLevel AT %QX1.2 : BOOL;
    T02_HighLevel AT %QX1.3 : BOOL;
    TankSelector AT %QX1.4 : BOOL;
    T02_Pump AT %QX1.5 : BOOL;
    T01_Agitator AT %QX1.6 : BOOL;
    T02_Agitator AT %QX1.7 : BOOL;
    TransferPump AT %QX2.0 : BOOL;
    T01_Temp AT %QW1 : INT;
    T02_Temp AT %QW2 : INT;
    BalanceLowLevel AT %QX2.1 : BOOL;
    BalanceHighLevel AT %QX2.2 : BOOL;
    BoosterPump AT %QX2.3 : BOOL;
    PreHeatTemp AT %QW3 : INT;
    HotWaterValve AT %QW8 : INT;
    PastTempIn AT %QW4 : INT;
    PastTempOut AT %QW5 : INT;
    DivertValve_FB AT %QX2.4 : BOOL;
    DivertValve AT %QX2.5 : BOOL;
    HeatingValve AT %QW9 : INT;
    CoolTempOut AT %QW6 : INT;
    ChillWaterValve AT %QW10 : INT;
    T03_LowLevel AT %QX2.6 : BOOL;
    T03_HighLevel AT %QX2.7 : BOOL;
    T03_Temp AT %QW7 : INT;
    FillingPump AT %QX3.0 : BOOL;
    BatchRelease AT %QX3.1 : BOOL;
    CIP_WaterValve AT %QX3.2 : BOOL;
    CIP_CausticValve AT %QX3.3 : BOOL;
    CIP_AcidValve AT %QX3.4 : BOOL;
    CIP_ReturnPump AT %QX3.5 : BOOL;
    CIP_Temp AT %QW11 : INT;
    CIP_Active AT %QX3.6 : BOOL;
    EStop AT %QX3.7 : BOOL;
    PlantStart AT %QX4.0 : BOOL;
    PlantStop AT %QX4.1 : BOOL;
    AlarmReset AT %QX4.2 : BOOL;
    AlarmLamp AT %QX4.3 : BOOL;
    RunLamp AT %QX4.4 : BOOL;
  END_VAR
  VAR
    HoldTimeMet : BOOL;
    ProcessControl0 : ProcessControl;
    CoolingOK : BOOL;
  END_VAR
  VAR
    CIP_Start AT %QX5.1 : BOOL;
  END_VAR
  VAR
    CIP_Step : INT := 0;
    PlantState : INT := 0;
    PlantRunning : BOOL;
    AlarmActive : BOOL;
    AlarmCode : INT;
  END_VAR

  Pump := NOT(EStop) AND PlantRunning AND NOT(TankSelector) AND NOT(HighLevel) AND LowLevel AND NOT(Stop) AND (Pump OR Start);
  InletValve := NOT(T02_HighLevel) AND NOT(HighLevel) AND TankerArrival;
  ReceptionPump := NOT(T02_HighLevel) AND NOT(HighLevel) AND InletValveOpen AND TankerArrival;
  T02_Pump := NOT(EStop) AND PlantRunning AND TankSelector AND NOT(T02_HighLevel) AND NOT(Stop) AND (Start OR T02_Pump);
  T01_Agitator := NOT(TankSelector) AND NOT(LowLevel);
  T02_Agitator := TankSelector AND NOT(T02_LowLevel);
  TransferPump := NOT(EStop) AND PlantRunning AND NOT(CIP_Active) AND NOT(BalanceHighLevel) AND NOT(T02_LowLevel) AND NOT(LowLevel) AND Start;
  AlarmLamp := NOT(EStop);
  BoosterPump := NOT(EStop) AND PlantRunning AND NOT(CIP_Active) AND NOT(EStop) AND NOT(BalanceLowLevel) AND Start;
  DivertValve := NOT(EStop) AND DivertValve_FB AND HoldTimeMet;
  FillingPump := NOT(EStop) AND NOT(T03_HighLevel) AND CoolingOK;
  BatchRelease := NOT(EStop) AND NOT(T03_LowLevel) AND HoldTimeMet AND CoolingOK;
  ProcessControl0(Enable := NOT(EStop) AND BoosterPump, PlantStart := PlantStart, PlantStop := PlantStop, AlarmReset := AlarmReset, BalanceLowLevel := BalanceLowLevel);
  PlantState := ProcessControl0.PlantState;
  RunLamp := ProcessControl0.RunLamp;
  PlantRunning := ProcessControl0.PlantRunning;
  AlarmActive := ProcessControl0.AlarmActive;
  AlarmCode := ProcessControl0.AlarmCode;
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : TankLevel;
  END_RESOURCE
END_CONFIGURATION

(*DBG:char md5[] = "d2e39601f1b87b2128fdd6b65313bab1";*)
(*DBG:/**)
(*DBG: * This file is part of OpenPLC Runtime*)
(*DBG: **)
(*DBG: * Copyright (C) 2023 Autonomy, GP Orcullo*)
(*DBG: * Based on the work by GP Orcullo on Beremiz for uC*)
(*DBG: **)
(*DBG: * This program is free software; you can redistribute it and/or*)
(*DBG: * modify it under the terms of the GNU General Public License*)
(*DBG: * as published by the Free Software Foundation; either version 2*)
(*DBG: * of the License, or (at your option) any later version.*)
(*DBG: **)
(*DBG: * This program is distributed in the hope that it will be useful,*)
(*DBG: * but WITHOUT ANY WARRANTY; without even the implied warranty of*)
(*DBG: * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the*)
(*DBG: * GNU General Public License for more details.*)
(*DBG: **)
(*DBG: * You should have received a copy of the GNU General Public License*)
(*DBG: * along with this program; If not, see <http://www.gnu.org/licenses/>.*)
(*DBG: **)
(*DBG: */*)
(*DBG:*)
(*DBG:#include <stdbool.h>*)
(*DBG:*)
(*DBG:#include "iec_types_all.h"*)
(*DBG:#include "POUS.h"*)
(*DBG:*)
(*DBG:#define SAME_ENDIANNESS      0*)
(*DBG:#define REVERSE_ENDIANNESS   1*)
(*DBG:*)
(*DBG:uint8_t endianness;*)
(*DBG:*)
(*DBG:*)
(*DBG:extern TANKLEVEL RES0__INSTANCE0;*)
(*DBG:*)
(*DBG:static const struct {*)
(*DBG:    void *ptr;*)
(*DBG:    __IEC_types_enum type;*)
(*DBG:} debug_vars[] = {*)
(*DBG:    {&(RES0__INSTANCE0.TANKERARRIVAL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.INLETVALVEOPEN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.INLETVALVECLOSED), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.RECEPTIONFT), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.INLETVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.RECEPTIONPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.LOWLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.HIGHLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.START), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.STOP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T02_LOWLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T02_HIGHLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.TANKSELECTOR), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T02_PUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T01_AGITATOR), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T02_AGITATOR), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.TRANSFERPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T01_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T02_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.BALANCELOWLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.BALANCEHIGHLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.BOOSTERPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PREHEATTEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.HOTWATERVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PASTTEMPIN), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PASTTEMPOUT), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.DIVERTVALVE_FB), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.DIVERTVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.HEATINGVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.COOLTEMPOUT), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CHILLWATERVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T03_LOWLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T03_HIGHLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.T03_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.FILLINGPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.BATCHRELEASE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_WATERVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_CAUSTICVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_ACIDVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_RETURNPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_ACTIVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.ESTOP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PLANTSTART), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PLANTSTOP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.ALARMRESET), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.ALARMLAMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.RUNLAMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.HOLDTIMEMET), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ENABLE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PREHEATTEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T01_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T02_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.BOOSTERPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.HOTWATERVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARMLAMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPREHEAT.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET01TEMP.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET02TEMP.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PREHEAT_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T01_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T02_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PREHEAT_SP), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PREHEAT_HYST), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.STORAGE_TEMP_HI), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_PREHEATHIGH), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_PREHEATLOW), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_T01_TEMPHIGH), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_T02_TEMPHIGH), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.PT), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.Q), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.ET), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.STATE), SINT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.PREV_IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.CURRENT_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TPREHEATTIMEOUT.START_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PREHEAT_TIMEOUT), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PASTTEMPIN), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PASTTEMPOUT), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTIN.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALEPASTOUT.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PASTIN_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PASTOUT_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PAST_SP), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PAST_HYST), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.HOLDTIMEMET), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.PT), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.Q), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.ET), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.STATE), SINT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.PREV_IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.CURRENT_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.THOLDTIMER.START_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.HOLD_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_PASTTEMPLOW), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_DIVERTFAULT), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.DIVERTVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.HEATINGVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.DIVERTVALVE_FB), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.COOLTEMPOUT), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T03_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECOOLOUT.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALET03TEMP.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.COOLOUT_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T03_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.COOL_SP), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.COOL_HYST), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.T03_TEMP_MAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_COOLTEMPHIGH), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_T03_TEMPHIGH), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CHILLWATERVALVE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.COOLINGOK), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_START), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_TEMP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.RAWVALUE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.RANGEMAX), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.SCALEDVALUE), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.FBSCALECIPTEMP.RAWREAL), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_TEMP_C), REAL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_STEP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.PT), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.Q), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.ET), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.STATE), SINT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.PREV_IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.CURRENT_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TCIP_STEP.START_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_RINSE_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_CAUSTIC_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_ACID_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARM_CIP_TEMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_ACTIVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_WATERVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_CAUSTICVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_ACIDVALVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.CIP_RETURNPUMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PLANTSTART), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PLANTSTOP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARMRESET), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PLANTSTATE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.EN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.ENO), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.PT), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.Q), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.ET), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.STATE), SINT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.PREV_IN), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.CURRENT_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.TSTARTUP.START_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.STARTUP_TIME), TIME_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ANYALARM), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.BALANCELOWLEVEL), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.RUNLAMP), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.PLANTRUNNING), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARMACTIVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARMCODE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PROCESSCONTROL0.ALARMLATCHED), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.COOLINGOK), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_START), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.CIP_STEP), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PLANTSTATE), INT_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.PLANTRUNNING), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.ALARMACTIVE), BOOL_ENUM},*)
(*DBG:    {&(RES0__INSTANCE0.ALARMCODE), INT_ENUM},*)
(*DBG:};*)
(*DBG:*)
(*DBG:#define VAR_COUNT               214*)
(*DBG:*)
(*DBG:uint16_t get_var_count(void)*)
(*DBG:{*)
(*DBG:    return VAR_COUNT;*)
(*DBG:}*)
(*DBG:*)
(*DBG:size_t get_var_size(size_t idx)*)
(*DBG:{*)
(*DBG:    if (idx >= VAR_COUNT)*)
(*DBG:    {*)
(*DBG:        return 0;*)
(*DBG:    }*)
(*DBG:    switch (debug_vars[idx].type) {*)
(*DBG:    case INT_ENUM:*)
(*DBG:        return sizeof(INT);*)
(*DBG:    case REAL_ENUM:*)
(*DBG:        return sizeof(REAL);*)
(*DBG:    case BOOL_ENUM:*)
(*DBG:        return sizeof(BOOL);*)
(*DBG:    case SINT_ENUM:*)
(*DBG:        return sizeof(SINT);*)
(*DBG:    case TIME_ENUM:*)
(*DBG:        return sizeof(TIME);*)
(*DBG:    default:*)
(*DBG:        return 0;*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void *get_var_addr(size_t idx)*)
(*DBG:{*)
(*DBG:    void *ptr = debug_vars[idx].ptr;*)
(*DBG:*)
(*DBG:    switch (debug_vars[idx].type) {*)
(*DBG:    case INT_ENUM:*)
(*DBG:        return (void *)&((__IEC_INT_t *) ptr)->value;*)
(*DBG:    case REAL_ENUM:*)
(*DBG:        return (void *)&((__IEC_REAL_t *) ptr)->value;*)
(*DBG:    case BOOL_ENUM:*)
(*DBG:        return (void *)&((__IEC_BOOL_t *) ptr)->value;*)
(*DBG:    case SINT_ENUM:*)
(*DBG:        return (void *)&((__IEC_SINT_t *) ptr)->value;*)
(*DBG:    case TIME_ENUM:*)
(*DBG:        return (void *)&((__IEC_TIME_t *) ptr)->value;*)
(*DBG:    default:*)
(*DBG:        return 0;*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void force_var(size_t idx, bool forced, void *val)*)
(*DBG:{*)
(*DBG:    void *ptr = debug_vars[idx].ptr;*)
(*DBG:*)
(*DBG:    if (forced) {*)
(*DBG:        size_t var_size = get_var_size(idx);*)
(*DBG:        switch (debug_vars[idx].type) {*)
(*DBG:        case INT_ENUM: {*)
(*DBG:            memcpy(&((__IEC_INT_t *) ptr)->value, val, var_size);*)
(*DBG:            //((__IEC_INT_t *) ptr)->value = *((INT *) val);*)
(*DBG:            ((__IEC_INT_t *) ptr)->flags |= __IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:        case REAL_ENUM: {*)
(*DBG:            memcpy(&((__IEC_REAL_t *) ptr)->value, val, var_size);*)
(*DBG:            //((__IEC_REAL_t *) ptr)->value = *((REAL *) val);*)
(*DBG:            ((__IEC_REAL_t *) ptr)->flags |= __IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:        case BOOL_ENUM: {*)
(*DBG:            memcpy(&((__IEC_BOOL_t *) ptr)->value, val, var_size);*)
(*DBG:            //((__IEC_BOOL_t *) ptr)->value = *((BOOL *) val);*)
(*DBG:            ((__IEC_BOOL_t *) ptr)->flags |= __IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:        case SINT_ENUM: {*)
(*DBG:            memcpy(&((__IEC_SINT_t *) ptr)->value, val, var_size);*)
(*DBG:            //((__IEC_SINT_t *) ptr)->value = *((SINT *) val);*)
(*DBG:            ((__IEC_SINT_t *) ptr)->flags |= __IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:        case TIME_ENUM: {*)
(*DBG:            memcpy(&((__IEC_TIME_t *) ptr)->value, val, var_size);*)
(*DBG:            //((__IEC_TIME_t *) ptr)->value = *((TIME *) val);*)
(*DBG:            ((__IEC_TIME_t *) ptr)->flags |= __IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:        default:*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:    } else {*)
(*DBG:        switch (debug_vars[idx].type) {*)
(*DBG:        case INT_ENUM:*)
(*DBG:            ((__IEC_INT_t *) ptr)->flags &= ~__IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        case REAL_ENUM:*)
(*DBG:            ((__IEC_REAL_t *) ptr)->flags &= ~__IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        case BOOL_ENUM:*)
(*DBG:            ((__IEC_BOOL_t *) ptr)->flags &= ~__IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        case SINT_ENUM:*)
(*DBG:            ((__IEC_SINT_t *) ptr)->flags &= ~__IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        case TIME_ENUM:*)
(*DBG:            ((__IEC_TIME_t *) ptr)->flags &= ~__IEC_FORCE_FLAG;*)
(*DBG:            break;*)
(*DBG:        default:*)
(*DBG:            break;*)
(*DBG:        }*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void swap_bytes(void *ptr, size_t size) *)
(*DBG:{*)
(*DBG:    uint8_t *bytePtr = (uint8_t *)ptr;*)
(*DBG:    size_t i;*)
(*DBG:    for (i = 0; i < size / 2; ++i) *)
(*DBG:    {*)
(*DBG:        uint8_t temp = bytePtr[i];*)
(*DBG:        bytePtr[i] = bytePtr[size - 1 - i];*)
(*DBG:        bytePtr[size - 1 - i] = temp;*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void trace_reset(void)*)
(*DBG:{*)
(*DBG:    for (size_t i=0; i < VAR_COUNT; i++) *)
(*DBG:    {*)
(*DBG:        force_var(i, false, 0);*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void set_trace(size_t idx, bool forced, void *val)*)
(*DBG:{*)
(*DBG:    if (idx >= 0 && idx < VAR_COUNT) *)
(*DBG:    {*)
(*DBG:        if (endianness == REVERSE_ENDIANNESS)*)
(*DBG:        {*)
(*DBG:            // Aaaaarghhhh... Stupid AVR is Big Endian.*)
(*DBG:            swap_bytes(val, get_var_size(idx));*)
(*DBG:        }*)
(*DBG:*)
(*DBG:        force_var(idx, forced, val);*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)
(*DBG:void set_endianness(uint8_t value)*)
(*DBG:{*)
(*DBG:    if (value == SAME_ENDIANNESS || value == REVERSE_ENDIANNESS)*)
(*DBG:    {*)
(*DBG:        endianness = value;*)
(*DBG:    }*)
(*DBG:}*)
(*DBG:*)