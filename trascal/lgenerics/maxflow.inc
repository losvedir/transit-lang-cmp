{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*                                                                           *
*   Copyright(c) 2018-2022 A.Koverdyaev(avk)                                *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}

{ TGDirectInt64Net.THPrHelper.TArc }

constructor TGDirectInt64Net.THPrHelper.TArc.Create(aTarget: PNode; aReverse: PArc; aCap: TWeight);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := aCap;
  IsForward := True;
end;

constructor TGDirectInt64Net.THPrHelper.TArc.CreateReverse(aTarget: PNode; aReverse: PArc);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := 0;
  IsForward := False;
end;

function TGDirectInt64Net.THPrHelper.TArc.IsSaturated: Boolean;
begin
  Result := ResCap = 0;
end;

function TGDirectInt64Net.THPrHelper.TArc.IsResidual: Boolean;
begin
  Result := ResCap > 0;
end;

procedure TGDirectInt64Net.THPrHelper.TArc.Push(aFlow: TWeight);
begin
  ResCap -= aFlow;
  Target^.Excess += aFlow;
  Reverse^.ResCap += aFlow;
  Reverse^.Target^.Excess -= aFlow;
end;

{ TGDirectInt64Net.THPrHelper.TNode }

function TGDirectInt64Net.THPrHelper.TNode.GetColor: TVertexColor;
begin
  Result := TVertexColor(Distance);
end;

procedure TGDirectInt64Net.THPrHelper.TNode.SetColor(aValue: TVertexColor);
begin
  Distance := SizeInt(aValue);
end;

procedure TGDirectInt64Net.THPrHelper.TNode.Reset;
begin
  CurrentArc := FirstArc;
end;

{ TGDirectInt64Net.THPrHelper.TLevel }

function TGDirectInt64Net.THPrHelper.TLevel.IsEmpty: Boolean;
begin
  Result := (TopActive = nil) and (TopIdle = nil);
end;

procedure TGDirectInt64Net.THPrHelper.TLevel.AddActive(aNode: PNode);
begin
  aNode^.LevelNext := TopActive;
  TopActive := aNode;
end;

procedure TGDirectInt64Net.THPrHelper.TLevel.AddIdle(aNode: PNode);
var
  Next: PNode;
begin
  Next := TopIdle;
  TopIdle := aNode;
  aNode^.LevelNext := Next;
  if Next <> nil then
    Next^.LevelPrev := aNode;
end;

procedure TGDirectInt64Net.THPrHelper.TLevel.Activate(aNode: PNode);
begin
  RemoveIdle(aNode);
  AddActive(aNode);
end;

procedure TGDirectInt64Net.THPrHelper.TLevel.RemoveIdle(aNode: PNode);
var
  Next, Prev: PNode;
begin
  Next := aNode^.LevelNext;
  if TopIdle = aNode then // is on head of the list
    TopIdle := Next
  else
    begin
      Prev := aNode^.LevelPrev;
      Prev^.LevelNext := aNode^.LevelNext;
      if Next <> nil then
        Next^.LevelPrev := Prev;
    end;
end;

procedure TGDirectInt64Net.THPrHelper.TLevel.Clear(aLabel: SizeInt);
var
  Next: PNode;
begin
  Next := TopActive;
  while Next <> nil do
    begin
      Next^.Distance := aLabel;
      Next := Next^.LevelNext;
    end;
  TopActive := nil;
  Next := TopIdle;
  while Next <> nil do
    begin
      Next^.Distance := aLabel;
      Next := Next^.LevelNext;
    end;
  TopIdle  := nil;
end;

{ TGDirectInt64Net.THPrHelper }

procedure TGDirectInt64Net.THPrHelper.CreateResidualNet(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt);
var
  CurrArcIdx: TIntArray;
  I, J: SizeInt;
  p: PAdjItem;
begin
  FNodeCount := aGraph.VertexCount;
  System.SetLength(CurrArcIdx, FNodeCount);
  J := 0;
  for I := 0 to System.High(CurrArcIdx) do
    begin
      CurrArcIdx[I] := J;
      J += aGraph.DegreeI(I);
    end;

  System.SetLength(FNodes, Succ(FNodeCount));
  System.SetLength(FArcs, Succ(aGraph.EdgeCount * 2));
  FSource := @FNodes[aSource];
  FSink := @FNodes[aSink];

  for I := 0 to Pred(FNodeCount) do
    begin
      FNodes[I].FirstArc := @FArcs[CurrArcIdx[I]];
      FNodes[I].Excess := 0;
    end;

  for I := 0 to Pred(FNodeCount) do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        FArcs[CurrArcIdx[I]] := TArc.Create(@FNodes[J], @FArcs[CurrArcIdx[J]], p^.Data.Weight);
        FArcs[CurrArcIdx[J]] := TArc.CreateReverse(@FNodes[I], @FArcs[CurrArcIdx[I]]);
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  CurrArcIdx := nil;

  FArcs[System.High(FArcs)] :=
    TArc.Create(@FNodes[FNodeCount], @FArcs[System.High(FArcs)], 0);
  //sentinel node
  FNodes[FNodeCount].FirstArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].CurrentArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].LevelNext := nil;
  FNodes[FNodeCount].LevelPrev := nil;
  FNodes[FNodeCount].Excess := 0;
  FNodes[FNodeCount].Distance := FNodeCount;

  FSource^.Excess := MAX_WEIGHT;
  System.SetLength(FLevels, FNodeCount);
  FMaxLevel := System.High(FLevels);
  System.SetLength(FQueue, FNodeCount);
end;

procedure TGDirectInt64Net.THPrHelper.CreateResidualNetCap(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight);
var
  CurrArcIdx: TIntArray;
  I, J: SizeInt;
  p: PAdjItem;
begin
  //almost same as above, but also stores capacities of the arcs;
  FNodeCount := aGraph.VertexCount;
  System.SetLength(CurrArcIdx, FNodeCount);
  CurrArcIdx[0] := 0;
  J := aGraph.DegreeI(0);

  for I := 1 to System.High(CurrArcIdx) do
    begin
      CurrArcIdx[I] := J;
      J += aGraph.DegreeI(I);
    end;

  System.SetLength(FNodes, Succ(FNodeCount));
  System.SetLength(FArcs, Succ(aGraph.EdgeCount * 2));
  System.SetLength(FCaps, aGraph.EdgeCount * 2);
  FSource := @FNodes[aSource];
  FSink := @FNodes[aSink];

  for I := 0 to Pred(FNodeCount) do
    begin
      FNodes[I].FirstArc := @FArcs[CurrArcIdx[I]];
      FNodes[I].Excess := 0;
    end;

  for I := 0 to Pred(FNodeCount) do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        FCaps[CurrArcIdx[I]] := p^.Data.Weight;
        FCaps[CurrArcIdx[J]] := 0;
        FArcs[CurrArcIdx[I]] := TArc.Create(@FNodes[J], @FArcs[CurrArcIdx[J]], p^.Data.Weight);
        FArcs[CurrArcIdx[J]] := TArc.CreateReverse(@FNodes[I], @FArcs[CurrArcIdx[I]]);
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  CurrArcIdx := nil;

  FArcs[System.High(FArcs)] :=
    TArc.Create(@FNodes[FNodeCount], @FArcs[System.High(FArcs)], 0);
  //sentinel node
  FNodes[FNodeCount].FirstArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].CurrentArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].LevelNext := nil;
  FNodes[FNodeCount].LevelPrev := nil;
  FNodes[FNodeCount].Excess := 0;
  FNodes[FNodeCount].Distance := FNodeCount;

  FSource^.Excess := aReqFlow;
  System.SetLength(FLevels, FNodeCount);
  FMaxLevel := System.High(FLevels);
  System.SetLength(FQueue, FNodeCount);
end;

procedure TGDirectInt64Net.THPrHelper.ClearLabels;
var
  I: SizeInt;
begin
  for I := 0 to  System.High(FNodes) do
    FNodes[I].Distance := FNodeCount;
end;

procedure TGDirectInt64Net.THPrHelper.GlobalRelabel;
var
  CurrNode, NextNode: PNode;
  CurrArc: PArc;
  Dist: SizeInt;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  System.FillChar(Pointer(FLevels)^, Succ(FMaxLevel) * SizeOf(TLevel), 0);
  FMaxLevel := 0;
  FMaxActiveLevel := NULL_INDEX;
  FMinActiveLevel := FNodeCount;
  ClearLabels;
  FSink^.Distance := 0;
  CurrNode := FSink;
  FQueue[qTail] := FSink;
  Inc(qTail);
  while qHead < qTail do
    begin
      CurrNode := FQueue[qHead];
      Inc(qHead);
      Dist := Succ(CurrNode^.Distance);
      CurrArc := CurrNode^.FirstArc;
      while CurrArc < (CurrNode + 1)^.FirstArc do
        begin
          NextNode := CurrArc^.Target;
          if (NextNode^.Distance = FNodeCount) and CurrArc^.Reverse^.IsResidual then
            begin
              NextNode^.Distance := Dist;
              NextNode^.Reset;
              if Dist > FMaxLevel then
                FMaxLevel := Dist;
              if NextNode^.Excess > 0 then
                begin
                  FLevels[Dist].AddActive(NextNode);
                  if Dist > FMaxActiveLevel then
                    FMaxActiveLevel := Dist;
                  if Dist < FMinActiveLevel then
                    FMinActiveLevel := Dist;
                end
              else
                FLevels[Dist].AddIdle(NextNode);
              FQueue[qTail] := NextNode;
              Inc(qTail);
            end;
          Inc(CurrArc);
        end;
    end;
end;

procedure TGDirectInt64Net.THPrHelper.RemoveGap(aLayer: SizeInt);
var
  I: SizeInt;
begin
  for I := Succ(aLayer) to FMaxLevel do
    FLevels[I].Clear(FNodeCount);
  FMaxActiveLevel := Pred(aLayer);
  FMaxLevel := FMaxActiveLevel;
end;

function TGDirectInt64Net.THPrHelper.Push(aNode: PNode): Boolean;
var
  CurrArc: PArc;
  NextNode: PNode;
  Dist: SizeInt;
begin
  Dist := Pred(aNode^.Distance);
  while aNode^.CurrentArc < (aNode + 1)^.FirstArc do
    begin
      CurrArc := aNode^.CurrentArc;
      NextNode := CurrArc^.Target;
      if (NextNode^.Distance = Dist) and CurrArc^.IsResidual then
        //arc is not saturated and target belongs to the next layer -> arc is admissible
        begin
          if (Dist > 0) and (NextNode^.Excess = 0) then //-> NextNode in idle list
            begin
              FLevels[Dist].Activate(NextNode);
              if Dist < FMinActiveLevel then
                FMinActiveLevel := Dist;
            end;
          CurrArc^.Push(wMin(aNode^.Excess, CurrArc^.ResCap));
          if aNode^.Excess = 0 then
            break;
        end;
      Inc(aNode^.CurrentArc);
    end;
  Result := aNode^.CurrentArc < (aNode + 1)^.FirstArc;
end;

procedure TGDirectInt64Net.THPrHelper.Relabel(aNode: PNode);
var
  CurrArc: PArc;
  MinArc: PArc = nil;
  Dist: SizeInt;
begin
  Dist := FNodeCount;
  aNode^.Distance := FNodeCount;
  CurrArc := aNode^.FirstArc;
  while CurrArc < (aNode + 1)^.FirstArc do
    begin
      if CurrArc^.IsResidual and (CurrArc^.Target^.Distance < Dist) then
        begin
          Dist := CurrArc^.Target^.Distance;
          MinArc := CurrArc;
        end;
      Inc(CurrArc);
    end;
  Inc(Dist);
  if Dist < FNodeCount then
    begin
      aNode^.Distance := Dist;
      aNode^.CurrentArc := MinArc;
      if Dist > FMaxLevel then
        FMaxLevel := Dist;
      if aNode^.Excess > 0 then
        begin
          FLevels[Dist].AddActive(aNode);
          if Dist > FMaxActiveLevel then
            FMaxActiveLevel := Dist;
          if Dist < FMinActiveLevel then
            FMinActiveLevel := Dist;
        end
      else
        FLevels[Dist].AddIdle(aNode);
    end;
end;

procedure TGDirectInt64Net.THPrHelper.Execute;
var
  CurrNode: PNode;
  TimeToGlobalRelable, OldMaxActive: SizeInt;
  RelableCount: SizeInt = 0;
begin
  GlobalRelabel;
  TimeToGlobalRelable := FNodeCount;
  while FMaxActiveLevel >= FMinActiveLevel do
    begin
      CurrNode := FLevels[FMaxActiveLevel].TopActive;
      if CurrNode <> nil then
        begin
          OldMaxActive := FMaxActiveLevel;
          FLevels[OldMaxActive].TopActive := CurrNode^.LevelNext;
          if not Push(CurrNode) then
            begin
              Relabel(CurrNode);
              Inc(RelableCount);
              if FLevels[OldMaxActive].IsEmpty then
                RemoveGap(OldMaxActive);
              if RelableCount = TimeToGlobalRelable then
                begin
                  GlobalRelabel;
                  RelableCount := 0;
                end;
            end
          else
            FLevels[OldMaxActive].AddIdle(CurrNode);
        end
      else
        Dec(FMaxActiveLevel);
    end;
end;

function TGDirectInt64Net.THPrHelper.CreateArcFlows: TEdgeArray;
var
  I, J: SizeInt;
  CurrArc: PArc;
begin
  System.SetLength(Result{%H-}, Pred(System.Length(FArcs)) div 2);
  J := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            begin
              Result[J] := TWeightEdge.Create(I, CurrArc^.Target - PNode(FNodes), CurrArc^.Reverse^.ResCap);
              Inc(J);
            end;
          Inc(CurrArc);
        end;
    end;
end;

function TGDirectInt64Net.THPrHelper.RecoverFlow: TEdgeArray;
var
  CurrNode, NextNode, RootNode, RestartNode: PNode;
  StackTop: PNode = nil;
  StackBottom: PNode = nil;
  CurrArc: PArc;
  Delta: TWeight;
begin
  CurrNode := Pointer(FNodes);
  while CurrNode < PNode(FNodes) + FNodeCount do
    begin
      CurrNode^.Color := vcWhite;
      CurrNode^.Parent := nil;
      CurrNode^.Reset;
      CurrArc := CurrNode^.FirstArc;
      while CurrArc < (CurrNode + 1)^.FirstArc do
        begin
          if CurrArc^.Target = CurrNode then
            CurrArc^.ResCap := FCaps[CurrArc - PArc(FArcs)];
          Inc(CurrArc);
        end;
      Inc(CurrNode);
    end;

  CurrNode := Pointer(FNodes);
  while CurrNode < PNode(FNodes) + FNodeCount do
    begin
      if (CurrNode^.Color = vcWhite) and (CurrNode^.Excess > 0) and
         (CurrNode <> FSource) and (CurrNode <> FSink) then
           begin
             RootNode := CurrNode;
             RootNode^.Color := vcGray;
             repeat
               while CurrNode^.CurrentArc < (CurrNode + 1)^.FirstArc do
                 begin
                   CurrArc := CurrNode^.CurrentArc;
                   if (FCaps[CurrArc - PArc(FArcs)] = 0) and CurrArc^.IsResidual and
                      (CurrArc^.Target <> FSource) and (CurrArc^.Target <> FSink) then
                     begin
                       NextNode := CurrArc^.Target;
                       if NextNode^.Color = vcWhite then
                         begin
                           NextNode^.Color := vcGray;
                           NextNode^.Parent := CurrNode;
                           CurrNode := NextNode;
                           break;
                         end
                       else
                         if NextNode^.Color = vcGray then
                           begin
                             //
                             Delta := CurrArc^.ResCap;
                             while True do
                               begin
                                 Delta := wMin(Delta, NextNode^.CurrentArc^.ResCap);
                                 if NextNode = CurrNode then
                                   break
                                 else
                                   NextNode := NextNode^.CurrentArc^.Target;
                               end;
                             //
                             NextNode := CurrNode;
                             while True do
                               begin
                                 CurrArc := NextNode^.CurrentArc;
                                 CurrArc^.ResCap -= Delta;
                                 CurrArc^.Reverse^.ResCap += Delta;
                                 NextNode := CurrArc^.Target;
                                 if NextNode = CurrNode then
                                   break;
                               end;
                             //
                             RestartNode := CurrNode;
                             NextNode := CurrNode^.CurrentArc^.Target;
                             while NextNode <> CurrNode do
                               begin
                                 CurrArc := NextNode^.CurrentArc;
                                 if (NextNode^.Color = vcWhite) or CurrArc^.IsSaturated then
                                   begin
                                     NextNode^.CurrentArc^.Target^.Color := vcWhite;
                                     if NextNode^.Color <> vcWhite then
                                       RestartNode := NextNode;
                                   end;
                                 NextNode := CurrArc^.Target;
                               end;
                             //
                             if RestartNode <> CurrNode then
                               begin
                                 CurrNode := RestartNode;
                                 Inc(CurrNode^.CurrentArc);
                                 break;
                               end;
                             //
                           end;
                     end;
                   Inc(CurrNode^.CurrentArc);
                 end;
               //
               if CurrNode^.CurrentArc >= (CurrNode + 1)^.FirstArc then
                 begin
                   CurrNode^.Color := vcBlack;
                   if CurrNode <> FSource then
                     if StackBottom = nil then
                       begin
                         StackBottom := CurrNode;
                         StackTop := CurrNode;
                       end
                     else
                       begin
                         CurrNode^.OrderNext := StackTop;
                         StackTop := CurrNode;
                       end;
                   if CurrNode <> RootNode then
                     begin
                       CurrNode := CurrNode^.Parent;
                       Inc(CurrNode^.CurrentArc);
                     end
                   else
                     break;
                 end;
             until False;
           end;
      Inc(CurrNode);
    end;

  if StackBottom <> nil then
    begin
      CurrNode := StackTop;
      repeat
        CurrArc := CurrNode^.FirstArc;
        while CurrNode^.Excess > 0 do
          begin
            if (FCaps[CurrArc - PArc(FArcs)] = 0) and CurrArc^.IsResidual then
              CurrArc^.Push(wMin(CurrNode^.Excess, CurrArc^.ResCap));
            Inc(CurrArc);
          end;
        if CurrNode = StackBottom then
          break
        else
          CurrNode := CurrNode^.OrderNext;
      until False;
    end;
  Result := CreateArcFlows;
end;

function TGDirectInt64Net.THPrHelper.GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt): TWeight;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Execute;
  Result := FSink^.Excess;
end;

function TGDirectInt64Net.THPrHelper.GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  out a: TEdgeArray): TWeight;
begin
  CreateResidualNetCap(aGraph, aSource, aSink, MAX_WEIGHT);
  Execute;
  FLevels := nil;
  Result := FSink^.Excess;
  a := RecoverFlow;
end;

function TGDirectInt64Net.THPrHelper.GetMinCut(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  out s: TIntArray): TWeight;
var
  I, J: SizeInt;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Execute;
  FLevels := nil;
  Result := FSink^.Excess;
  System.SetLength(s{%H-}, ARRAY_INITIAL_SIZE);
  J := 0;
  for I := 0 to Pred(FNodeCount) do
    if FNodes[I].Distance = FNodeCount then
      begin
        if System.Length(s) = J then
          System.SetLength(s, J shl 1);
        s[J] := I;
        Inc(J);
      end;
  System.SetLength(s, J);
end;

function TGDirectInt64Net.THPrHelper.GetFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out a: TEdgeArray): TWeight;
begin
  CreateResidualNetCap(aGraph, aSource, aSink, aReqFlow);
  Execute;
  FLevels := nil;
  Result := FSink^.Excess;
  a := RecoverFlow;
end;

function TGDirectInt64Net.THPrHelper.GetFlowMap(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out m: TWeightArcMap): TWeight;
var
  e: TWeightEdge;
begin
  CreateResidualNetCap(aGraph, aSource, aSink, aReqFlow);
  Execute;
  FLevels := nil;
  Result := FSink^.Excess;
  for e in RecoverFlow do
    m.Add(e.Edge, e.Weight);
end;

{ TGDirectInt64Net.TDinitzHelper.TArc }

constructor TGDirectInt64Net.TDinitzHelper.TArc.Create(aTarget: PNode; aReverse: PArc; aCap: TWeight);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := aCap;
  IsForward := True;
end;

constructor TGDirectInt64Net.TDinitzHelper.TArc.CreateReverse(aTarget: PNode; aReverse: PArc);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := 0;
  IsForward := False;
end;

procedure TGDirectInt64Net.TDinitzHelper.TArc.Push(aFlow: TWeight);
begin
  ResCap -= aFlow;
  Reverse^.ResCap += aFlow;
end;

{ TGDirectInt64Net.TDinitzHelper.TNode }

procedure TGDirectInt64Net.TDinitzHelper.TNode.Reset;
begin
  CurrentArc := FirstArc;
end;

{ TGDirectInt64Net.TDinitzHelper }

procedure TGDirectInt64Net.TDinitzHelper.CreateResidualNet(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt);
var
  CurrArcIdx: TIntArray;
  I, J: SizeInt;
  p: PAdjItem;
  Cap: TWeight;
begin
  FNodeCount := aGraph.VertexCount;
  System.SetLength(CurrArcIdx{%H-}, FNodeCount);
  J := 0;
  for I := 0 to System.High(CurrArcIdx) do
    begin
      CurrArcIdx[I] := J;
      J += aGraph.DegreeI(I);
    end;

  System.SetLength(FNodes, Succ(FNodeCount));
  FSource := @FNodes[aSource];
  FSink := @FNodes[aSink];
  System.SetLength(FArcs, Succ(aGraph.EdgeCount * 2));

  for I := 0 to Pred(FNodeCount) do
    FNodes[I].FirstArc := @FArcs[CurrArcIdx[I]];

  FEpsilon := 0;
  for I := 0 to Pred(FNodeCount) do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        Cap := p^.Data.Weight;
        if Cap > FEpsilon then
          FEpsilon := Cap;
        FArcs[CurrArcIdx[I]] := TArc.Create(@FNodes[J], @FArcs[CurrArcIdx[J]], Cap);
        FArcs[CurrArcIdx[J]] := TArc.CreateReverse(@FNodes[I], @FArcs[CurrArcIdx[I]]);
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;
  CurrArcIdx := nil;
  FScaleFactor := wMax(MIN_SCALE, BsrQWord(FEpsilon));

  FArcs[System.High(FArcs)] :=
    TArc.Create(@FNodes[FNodeCount], @FArcs[System.High(FArcs)], 0);
  //sentinel node
  FNodes[FNodeCount].FirstArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].CurrentArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].Distance := NULL_INDEX;

  System.SetLength(FQueue, aGraph.VertexCount);
end;

procedure TGDirectInt64Net.TDinitzHelper.ClearLabels;
var
  I: SizeInt;
begin
  for I := 0 to Pred(FNodeCount) do
    FNodes[I].Distance := NULL_INDEX;
  FSource^.Distance := 0;
  FSource^.Reset;
end;

function TGDirectInt64Net.TDinitzHelper.BuildLevelGraph: Boolean;
var
  Curr, Next: PNode;
  CurrArc: PArc;
  Dist: SizeInt;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  ClearLabels;
  FQueue[qTail] := FSource;
  Inc(qTail);
  while (qHead < qTail) and (FSink^.Distance = NULL_INDEX) do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      Dist := Succ(Curr^.Distance);
      CurrArc := Curr^.FirstArc;
      while CurrArc < (Curr + 1)^.FirstArc do
        begin
          Next := CurrArc^.Target;
          if (Next^.Distance = NULL_INDEX) and (CurrArc^.ResCap > FEpsilon) then
            begin
              Next^.Reset;
              Next^.Distance := Dist;
              FQueue[qTail] := Next;
              Inc(qTail);
            end;
          Inc(CurrArc);
        end;
    end;
  Result := FSink^.Distance <> NULL_INDEX;
end;

function TGDirectInt64Net.TDinitzHelper.FindBlockingFlow(aRoot: PNode; aFlow: TWeight): TWeight;
var
  Arc: PArc;
begin
  if aFlow > 0 then
    if aRoot <> FSink then
      while aRoot^.CurrentArc < (aRoot + 1)^.FirstArc do
        begin
          Arc := aRoot^.CurrentArc;
          if Arc^.Target^.Distance = Succ(aRoot^.Distance) then
            begin
              Result := FindBlockingFlow(Arc^.Target, wMin(aFlow, Arc^.ResCap));
              if Result > 0 then
                begin
                  Arc^.Push(Result);
                  exit;
                end;
            end;
          Inc(aRoot^.CurrentArc);
        end
    else
      exit(aFlow);
  Result := 0;
end;

function TGDirectInt64Net.TDinitzHelper.Execute: TWeight;
var
  Flow: TWeight;
begin
  Result := 0;
  while FEpsilon > 0 do
    begin
      FEpsilon := FEpsilon div FScaleFactor;
      while BuildLevelGraph do
        repeat
          Flow := FindBlockingFlow(FSource, TWeight.INF_VALUE);
          Result += Flow;
        until Flow = 0;
    end;
end;

function TGDirectInt64Net.TDinitzHelper.Execute(aReqFlow: TWeight): TWeight;
var
  Flow: TWeight;
begin
  Result := 0;
  while FEpsilon > 0 do
    begin
      FEpsilon := FEpsilon div FScaleFactor;
      while BuildLevelGraph do
        begin
          repeat
            Flow := FindBlockingFlow(FSource, aReqFlow - Result);
            Result += Flow;
          until Flow = 0;
          if Result >= aReqFlow then
            exit;
        end;
    end;
end;

function TGDirectInt64Net.TDinitzHelper.CreateArcFlows(aGraph: TGDirectInt64Net): TEdgeArray;
var
  I, J: SizeInt;
  CurrArc: PArc;
begin
  System.SetLength(Result{%H-}, aGraph.EdgeCount);
  J := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            begin
              Result[J] :=
                TWeightEdge.Create(I, CurrArc^.Target - PNode(FNodes), CurrArc^.Reverse^.ResCap);
              Inc(J);
            end;
          Inc(CurrArc);
        end;
    end;
end;

function TGDirectInt64Net.TDinitzHelper.GetMaxFlow(aGraph: TGDirectInt64Net; aSource,
  aSink: SizeInt): TWeight;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Result := Execute;
end;

function TGDirectInt64Net.TDinitzHelper.GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  out a: TEdgeArray): TWeight;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Result := Execute;
  a := CreateArcFlows(aGraph);
end;

function TGDirectInt64Net.TDinitzHelper.GetMinCut(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  out s: TIntArray): TWeight;
var
  I, J: SizeInt;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Result := Execute;
  System.SetLength(s{%H-}, ARRAY_INITIAL_SIZE);
  J := 0;
  for I := 0 to Pred(FNodeCount) do
    if FNodes[I].Distance <> NULL_INDEX then
      begin
        if System.Length(s) = J then
          System.SetLength(s, J shl 1);
        s[J] := I;
        Inc(J);
      end;
  System.SetLength(s, J);
end;

function TGDirectInt64Net.TDinitzHelper.GetFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out a: TEdgeArray): TWeight;
begin
  CreateResidualNet(aGraph, aSource, aSink);
  Result := Execute(aReqFlow);
  a := CreateArcFlows(aGraph);
end;



