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

{ TGCostedInt64Net.TSspMcfHelper.TArc }

constructor TGCostedInt64Net.TSspMcfHelper.TArc.Create(aTarget: PNode; aReverse: PArc; aCap: TWeight; aCost: TCost);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := aCap;
  Cost := aCost;
  IsForward := True;
end;

constructor TGCostedInt64Net.TSspMcfHelper.TArc.CreateReverse(aTarget: PNode; aReverse: PArc; aCost: TCost);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := 0;
  Cost := -aCost;
  IsForward := False;
end;

procedure TGCostedInt64Net.TSspMcfHelper.TArc.Push(aFlow: TWeight);
begin
  ResCap -= aFlow;
  Reverse^.ResCap += aFlow;
end;

{ TGCostedInt64Net.TSspMcfHelper }

procedure TGCostedInt64Net.TSspMcfHelper.CreateResidualNet(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight);
var
  CurrArcIdx: TIntArray;
  I, J: SizeInt;
  c: TCost;
  p: PAdjItem;
begin
  FGraph := aGraph;
  FNodeCount := aGraph.VertexCount;
  FRequestFlow := aReqFlow;
  System.SetLength(CurrArcIdx, FNodeCount);
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
  for I := 0 to Pred(FNodeCount) do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        c := p^.Data.Cost;
        FArcs[CurrArcIdx[I]] := TArc.Create(@FNodes[J], @FArcs[CurrArcIdx[J]], p^.Data.Weight, c);
        FArcs[CurrArcIdx[J]] := TArc.CreateReverse(@FNodes[I], @FArcs[CurrArcIdx[I]], c);
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  CurrArcIdx := nil;

  FArcs[System.High(FArcs)] :=
    TArc.Create(@FNodes[FNodeCount], @FArcs[System.High(FArcs)], 0, 0);
  //sentinel node
  FNodes[FNodeCount].FirstArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].PathArc := nil;
  FNodes[FNodeCount].Parent := nil;
  FNodes[FNodeCount].Price := 0;
  FNodes[FNodeCount].PathMinCap := 0;

  FInQueue.Capacity := FNodeCount;
  FReached.Capacity := FNodeCount;
  FQueue := THeap.Create(FNodeCount);
end;

procedure TGCostedInt64Net.TSspMcfHelper.SearchInit;
var
  I: SizeInt;
begin
  for I := 0 to Pred(FNodeCount) do
    FNodes[I].Price := MAX_COST;
  FSource^.Price := 0;
  FSource^.PathMinCap := MAX_WEIGHT;
  FSink^.Parent := nil;
end;

function TGCostedInt64Net.TSspMcfHelper.SetNodePrices: Boolean;
var
  Buf: TIntArray;
  Active: TBoolVector;
  Queue, TreePrev, TreeNext, Level: PSizeInt;
  Curr, Next, Prev, Post, Test, CurrLevel, qHead, qTail: SizeInt;
  CurrArc: PArc;
  NodePrice: TCost;
begin
  SearchInit;
  Buf := TIntArray.Construct(FGraph.VertexCount * 4, NULL_INDEX);
  Queue := Pointer(Buf);
  TreePrev := Queue + FGraph.VertexCount;
  TreeNext := TreePrev + FGraph.VertexCount;
  Level := TreeNext + FGraph.VertexCount;
  Active.Capacity := FNodeCount;
  qHead := 0;
  qTail := 0;
  FSource^.Parent := FSource;
  Next := FSource - PNode(FNodes);
  TreePrev[Next] := Next;
  TreeNext[Next] := Next;
  Queue[qTail] := Next;
  Inc(qTail);
  Active.UncBits[Next] := True;
  while qHead <> qTail do
    begin
      Curr := Queue[qHead];
      Inc(qHead);
      if qHead = FNodeCount then
        qHead := 0;
      FInQueue.UncBits[Curr] := False;
      if not Active.UncBits[Curr] then
        continue;
      Active.UncBits[Curr] := False; /////////////
      CurrArc := FNodes[Curr].FirstArc;
      NodePrice := FNodes[Curr].Price;
      while CurrArc < FNodes[Succ(Curr)].FirstArc do
        begin
          if CurrArc^.ResCap > 0 then
            begin
              Next := CurrArc^.Target - PNode(FNodes);
              if NodePrice + CurrArc^.Cost < FNodes[Next].Price then
                begin
                  FNodes[Next].Price := NodePrice + CurrArc^.Cost;
                  FNodes[Next].PathMinCap := wMin(FNodes[Curr].PathMinCap, CurrArc^.ResCap);
                  if TreePrev[Next] <> NULL_INDEX then
                    begin
                      Prev := TreePrev[Next];
                      Test := Next;
                      CurrLevel := 0;
                      repeat
                        if Test = Curr then
                          exit(False);
                        CurrLevel += Level[Test];
                        TreePrev[Test] := NULL_INDEX;
                        Level[Test] := NULL_INDEX;
                        Active.UncBits[Test] := False;
                        Test := TreeNext[Test];
                      until CurrLevel < 0;
                      Dec(Level[FNodes[Next].Parent - PNode(FNodes)]);
                      TreeNext[Prev] := Test;
                      TreePrev[Test] := Prev;
                    end;
                  FNodes[Next].Parent := @FNodes[Curr];
                  FNodes[Next].PathArc := CurrArc;
                  Inc(Level[Curr]);
                  Post := TreeNext[Curr];
                  TreeNext[Curr] := Next;
                  TreePrev[Next] := Curr;
                  TreeNext[Next] := Post;
                  TreePrev[Post] := Next;
                  if not FInQueue.UncBits[Next] then
                    begin
                      Queue[qTail] := Next;
                      Inc(qTail);
                      if qTail = FNodeCount then
                        qTail := 0;
                      FInQueue.UncBits[Next] := True;
                    end;
                  Active.UncBits[Next] := True;
                end;
            end;
          Inc(CurrArc);
        end;
    end;
  FSource^.Parent := nil;
  Result := FSink^.Parent <> nil;
end;
{$PUSH}{$MACRO ON}
function TGCostedInt64Net.TSspMcfHelper.FindAugmentPath: Boolean;
var
  Node, NextNode: PNode;
  Arc: PArc;
  I: SizeInt;
  Item: TCostItem;
  NodePrice, RelaxPrice: TCost;
{$DEFINE UpdateNextNode :=
  NextNode^.PathMinCap := wMin(Node^.PathMinCap, Arc^.ResCap);
  NextNode^.Parent := Node;
  NextNode^.PathArc := Arc
}
begin
  FInQueue.ClearBits;
  FReached.ClearBits;
  FQueue.MakeEmpty;
  FSource^.PathArc := nil;
  FSource^.PathMinCap := MAX_WEIGHT;
  Item := TCostItem.Create(FSource - PNode(FNodes), 0);
  repeat
    Node := @FNodes[Item.Index];
    FNodes[Item.Index].Price += Item.Cost;
    FReached.UncBits[Item.Index] := True;
    if Node = FSink then
      break;
    Arc := Node^.FirstArc;
    NodePrice := Node^.Price;
    while Arc < (Node + 1)^.FirstArc do
      begin
        if Arc^.ResCap > 0 then
          begin
            NextNode := Arc^.Target;
            I := NextNode - PNode(FNodes);
            if not FReached.UncBits[I] then
              begin
                RelaxPrice := NodePrice + Arc^.Cost - NextNode^.Price;
                if not FInQueue.UncBits[I] then
                  begin
                    UpdateNextNode;
                    FQueue.Enqueue(I, TCostItem.Create(I, RelaxPrice));
                    FInQueue.UncBits[I] := True;
                  end
                else
                  if RelaxPrice < FQueue.GetItemPtr(I)^.Cost then
                    begin
                      UpdateNextNode;
                      FQueue.Update(I, TCostItem.Create(I, RelaxPrice));
                    end;
              end;
          end;
        Inc(Arc);
      end;
  until not FQueue.TryDequeue(Item);

  Result := FReached.UncBits[FSink - PNode(FNodes)];
  if Result then
    for I in FReached do
      FNodes[I].Price -= Item.Cost;
{$UNDEF UpdateNextNode}
end;
{$POP}
function TGCostedInt64Net.TSspMcfHelper.PushFlow(aRestFlow: TWeight): TWeight;
var
  Node: PNode;
begin
  Node := FSink;
  Result := wMin(aRestFlow, FSink^.PathMinCap);
  repeat
    if Node^.Parent <> nil then
      Node^.PathArc^.Push(Result);
    Node := Node^.Parent;
  until Node = nil;
end;

function TGCostedInt64Net.TSspMcfHelper.Execute: TWeight;
begin
  Result := 0;
  if not SetNodePrices then
    exit;
  repeat
    Result += PushFlow(FRequestFlow - Result);
  until (Result = FRequestFlow) or not FindAugmentPath;
end;

function TGCostedInt64Net.TSspMcfHelper.GetTotalCost: TCost;
var
  I: SizeInt;
  CurrArc: PArc;
begin
  Result := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            Result += CurrArc^.Reverse^.ResCap * CurrArc^.Cost;
          Inc(CurrArc);
        end;
    end;
end;

function TGCostedInt64Net.TSspMcfHelper.CreateArcFlows(out aTotalCost: TCost): TEdgeArray;
var
  I, J, Dst: SizeInt;
  CurrArc: PArc;
  w: TWeight;
begin
  System.SetLength(Result, Pred(System.Length(FArcs)) shr 1);
  J := 0;
  aTotalCost := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            begin
              Dst := CurrArc^.Target - PNode(FNodes);
              w := CurrArc^.Reverse^.ResCap;
              aTotalCost += w * CurrArc^.Cost;
              Result[J] := TWeightEdge.Create(I, Dst, w);
              Inc(J);
            end;
          Inc(CurrArc);
        end;
    end;
end;

function TGCostedInt64Net.TSspMcfHelper.GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out aTotalCost: TCost): TWeight;
begin
  if aReqFlow <= 0 then
    begin
      Result := 0;
      raise EGraphError.Create(SEMethodNotApplicable);
    end;
  CreateResidualNet(aGraph, aSource, aSink, aReqFlow);
  Result := Execute;
  if Result > 0 then
    aTotalCost := GetTotalCost;
end;

function TGCostedInt64Net.TSspMcfHelper.GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out aTotalCost: TCost; out a: TEdgeArray): TWeight;
begin
  if aReqFlow <= 0 then
    begin
      Result := 0;
      raise EGraphError.Create(SEMethodNotApplicable);
    end;
  CreateResidualNet(aGraph, aSource, aSink, aReqFlow);
  Result := Execute;
  if Result > 0 then
    a := CreateArcFlows(aTotalCost);
end;

{ TGCostedInt64Net.TCsMcfHelper.TArc }

constructor TGCostedInt64Net.TCsMcfHelper.TArc.Create(aTarget: PNode; aReverse: PArc; aCap: TWeight;
  aCost: TCost);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := aCap;
  Cost := aCost;
  IsForward := True;
end;

constructor TGCostedInt64Net.TCsMcfHelper.TArc.CreateReverse(aTarget: PNode; aReverse: PArc; aCost: TCost);
begin
  Target := aTarget;
  Reverse := aReverse;
  ResCap := 0;
  Cost := -aCost;
  IsForward := False;
end;

procedure TGCostedInt64Net.TCsMcfHelper.TArc.Push(aFlow: TWeight);
begin
  ResCap -= aFlow;
  Target^.Excess += aFlow;
  Reverse^.ResCap += aFlow;
  Reverse^.Target^.Excess -= aFlow;
end;

procedure TGCostedInt64Net.TCsMcfHelper.TArc.PushAll;
begin
  Target^.Excess += ResCap;
  Reverse^.ResCap += ResCap;
  Reverse^.Target^.Excess -= ResCap;
  ResCap := 0;
end;

{ TGCostedInt64Net.TCsMcfHelper.TNode }

procedure TGCostedInt64Net.TCsMcfHelper.TNode.Reset;
begin
  CurrArc := FirstArc;
end;

{ TGCostedInt64Net.TCsMcfHelper }

procedure TGCostedInt64Net.TCsMcfHelper.CreateResidualNet(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight);
var
  CurrArcIdx: TIntArray;
  I, J: SizeInt;
  c: TCost;
  p: PAdjItem;
begin
  FGraph := aGraph;
  FNodeCount := aGraph.VertexCount;
  FScaleFactor := TCost(FNodeCount) * ALPHA;
  FRequestFlow := aReqFlow;
  System.SetLength(CurrArcIdx, FNodeCount);
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
    begin
      FNodes[I].FirstArc := @FArcs[CurrArcIdx[I]];
      FNodes[I].CurrArc := @FArcs[CurrArcIdx[I]];
      FNodes[I].Price := 0;
      FNodes[I].Excess := 0;
    end;

  for I := 0 to Pred(FNodeCount) do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        c := p^.Data.Cost;
        FArcs[CurrArcIdx[I]] := TArc.Create(@FNodes[J], @FArcs[CurrArcIdx[J]], p^.Data.Weight, c);
        FArcs[CurrArcIdx[J]] := TArc.CreateReverse(@FNodes[I], @FArcs[CurrArcIdx[I]], c);
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  CurrArcIdx := nil;

  FArcs[System.High(FArcs)] :=
    TArc.Create(@FNodes[FNodeCount], @FArcs[System.High(FArcs)], 0, 0);
  //sentinel node
  FNodes[FNodeCount].FirstArc := @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].CurrArc :=  @FArcs[System.High(FArcs)];
  FNodes[FNodeCount].Price := 0;
  FNodes[FNodeCount].Excess := 0;

  FInQueue.Capacity := FNodeCount;
  FQueue.EnsureCapacity(FNodeCount);
end;

function TGCostedInt64Net.TCsMcfHelper.IndexOf(aNode: PNode): SizeInt;
begin
  Result := aNode - PNode(FNodes);
end;

function TGCostedInt64Net.TCsMcfHelper.PriceUpdate: Boolean;
var
  Queue, Parents, TreePrev, TreeNext, Level: TIntArray;
  InQueue, Active: TBoolVector;
  Curr, Next, Prev, Post, Test, CurrLevel, qLen, qHead, qTail: SizeInt;
  CurrArc: PArc;
  NodePrice: TCost;
begin
  qLen := Succ(FNodeCount);
  qHead := 0;
  Queue := TIntHelper.CreateRange(0, FNodeCount);
  Parents := FGraph.CreateIntArray(qLen, FNodeCount);
  TreePrev := FGraph.CreateIntArray(qLen, FNodeCount);
  TreeNext := FGraph.CreateIntArray(qLen, NULL_INDEX);
  Level := FGraph.CreateIntArray(qLen, NULL_INDEX);
  qTail := FNodeCount;
  InQueue.InitRange(FNodeCount);
  Active.InitRange(FNodeCount);
  while qHead <> qTail do
    begin
      Curr := Queue[qHead];
      Inc(qHead);
      if qHead = qLen then
        qHead := 0;
      InQueue.UncBits[Curr] := False;
      if not Active.UncBits[Curr] then
        continue;
      Active.UncBits[Curr] := False; /////////////
      CurrArc := FNodes[Curr].FirstArc;
      NodePrice := FNodes[Curr].Price;
      while CurrArc < FNodes[Succ(Curr)].FirstArc do
        begin
          if CurrArc^.ResCap > 0 then
            begin
              Next := IndexOf(CurrArc^.Target);
              if NodePrice + CurrArc^.Cost < FNodes[Next].Price then
                begin
                  FNodes[Next].Price := NodePrice + CurrArc^.Cost;
                  if TreePrev[Next] <> NULL_INDEX then
                    begin
                      Prev := TreePrev[Next];
                      Test := Next;
                      CurrLevel := 0;
                      repeat
                        if Test = Curr then
                          exit(False);
                        CurrLevel += Level[Test];
                        TreePrev[Test] := NULL_INDEX;
                        Level[Test] := NULL_INDEX;
                        Active.UncBits[Test] := False;
                        Test := TreeNext[Test];
                      until CurrLevel < 0;
                      Dec(Level[Parents[Next]]);
                      TreeNext[Prev] := Test;
                      TreePrev[Test] := Prev;
                    end;
                  Parents[Next] := Curr;
                  Inc(Level[Curr]);
                  Post := TreeNext[Curr];
                  TreeNext[Curr] := Next;
                  TreePrev[Next] := Curr;
                  TreeNext[Next] := Post;
                  TreePrev[Post] := Next;
                  if not InQueue.UncBits[Next] then
                    begin
                      Queue[qTail] := Next;
                      Inc(qTail);
                      if qTail = qLen then
                        qTail := 0;
                      InQueue.UncBits[Next] := True;
                    end;
                  Active.UncBits[Next] := True;
                end;
            end;
          Inc(CurrArc);
        end;
    end;
  Result := True;
end;

function TGCostedInt64Net.TCsMcfHelper.FindRequiredFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  out m: TWeightArcMap): Boolean;
var
  Helper: THPrHelper;
begin
  FResultFlow := Helper.GetFlowMap(aGraph, aSource, aSink, FRequestFlow, m);
  Result := FResultFlow > 0;
end;

function TGCostedInt64Net.TCsMcfHelper.FindInitSolution: Boolean;
var
  ArcMap: TWeightArcMap;
  I, Src, Dst: SizeInt;
  CostAbs: TCost;
begin
  FResultFlow := 0;
  if not PriceUpdate then
    exit(False);
  if not FindRequiredFlow(FGraph, IndexOf(FSource), IndexOf(FSink), ArcMap) then
    exit(False);
  FSource^.Excess += FResultFlow;
  FSink^.Excess -= FResultFlow;
  FEpsilon := 0;
  for I := 0 to Pred(System.High(FArcs)) do
    begin
      FArcs[I].Cost *= FScaleFactor;
      if FArcs[I].IsForward then
        begin
          CostAbs := Abs(FArcs[I].Cost);
          if CostAbs > FEpsilon then
            FEpsilon := CostAbs;
          Src := IndexOf(FArcs[I].Reverse^.Target);
          Dst := IndexOf(FArcs[I].Target);
          FArcs[I].Push(ArcMap[TIntEdge.Create(Src, Dst)]);
        end;
    end;
  if FEpsilon < 1 then
    FEpsilon := 1;
  Result := True;
end;

procedure TGCostedInt64Net.TCsMcfHelper.InitPhase;
var
  Arc: PArc;
  I: SizeInt;
  Price: TCost;
begin
  FInQueue.ClearBits;
  for I := 0 to Pred(FNodeCount) do
    begin
      Arc := FNodes[I].FirstArc;
      Price := FNodes[I].Price;
      while Arc < FNodes[Succ(I)].FirstArc do
        begin
          if (Arc^.ResCap > 0) and (Price + Arc^.Cost - FNodes[IndexOf(Arc^.Target)].Price <= -FEpsilon) then
            Arc^.PushAll;
          Inc(Arc);
        end;
    end;
  for I := 0 to Pred(FNodeCount) do
    if FNodes[I].Excess > 0 then
      begin
        FNodes[I].Reset;
        FQueue.Enqueue(@FNodes[I]);
        FInQueue.UncBits[I] := True;
      end;
end;

procedure TGCostedInt64Net.TCsMcfHelper.Discharge(aNode: PNode);
var
  NextNode: PNode;
  Arc: PArc;
  NodePrice, MinPrice: TCost;
begin
  while aNode^.Excess > 0 do
    begin
      NodePrice := aNode^.Price;
      while aNode^.CurrArc < (aNode + 1)^.FirstArc do
        begin
          Arc := aNode^.CurrArc;
          if Arc^.ResCap > 0 then
            begin
              NextNode := Arc^.Target;
              if NodePrice + Arc^.Cost - NextNode^.Price < 0 then
                begin
                  Arc^.Push(wMin(aNode^.Excess, Arc^.ResCap));
                  if (NextNode^.Excess > 0) and not FInQueue.UncBits[IndexOf(NextNode)] then
                    begin
                      FQueue.Enqueue(NextNode);
                      FInQueue.UncBits[IndexOf(NextNode)] := True;
                    end;
                end;
            end;
          Inc(aNode^.CurrArc);
        end;
      if aNode^.Excess > 0 then
        begin
          Arc := aNode^.FirstArc;
          MinPrice := MAX_COST;
          while Arc < (aNode + 1)^.FirstArc do
            begin
              if Arc^.ResCap > 0 then
                begin
                  NextNode := Arc^.Target;
                  if NodePrice + Arc^.Cost - NextNode^.Price < MinPrice then
                    MinPrice := NodePrice + Arc^.Cost - NextNode^.Price;
                end;
              Inc(Arc);
            end;
          aNode^.Price -= MinPrice + FEpsilon;
          aNode^.Reset;
        end
      else
        aNode^.Price -= FEpsilon; //todo: ???
    end;
end;

procedure TGCostedInt64Net.TCsMcfHelper.Execute;
var
  Node: PNode;
  NeedUpdate: Boolean = True;
begin
  repeat
    FEpsilon := CostMax(FEpsilon div ALPHA, 1);
    if NeedUpdate then
      PriceUpdate;
    InitPhase;
    NeedUpdate := FQueue.NonEmpty;
    while FQueue.TryDequeue(Node) do
      begin
        FInQueue.UncBits[IndexOf(Node)] := False;
        Discharge(Node{%H-});
      end;
  until FEpsilon = 1;
end;

function TGCostedInt64Net.TCsMcfHelper.GetTotalCost: TCost;
var
  I: SizeInt;
  CurrArc: PArc;
begin
  Result := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            Result += CurrArc^.Reverse^.ResCap * (CurrArc^.Cost div FScaleFactor);
          Inc(CurrArc);
        end;
    end;
end;

function TGCostedInt64Net.TCsMcfHelper.CreateArcFlows(out aTotalCost: TCost): TEdgeArray;
var
  I, J, Dst: SizeInt;
  CurrArc: PArc;
  w: TWeight;
begin
  System.SetLength(Result, Pred(System.Length(FArcs)) shr 1);
  J := 0;
  aTotalCost := 0;
  for I := 0 to Pred(FNodeCount) do
    begin
      CurrArc := FNodes[I].FirstArc;
      while CurrArc < FNodes[Succ(I)].FirstArc do
        begin
          if CurrArc^.IsForward then
            begin
              Dst := CurrArc^.Target - PNode(FNodes);
              w := CurrArc^.Reverse^.ResCap;
              aTotalCost += w * (CurrArc^.Cost div FScaleFactor);
              Result[J] := TWeightEdge.Create(I, Dst, w);
              Inc(J);
            end;
          Inc(CurrArc);
        end;
    end;
end;

function TGCostedInt64Net.TCsMcfHelper.GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out aTotalCost: TCost): TWeight;
begin
  if aReqFlow <= 0 then
    begin
      Result := 0;
      raise EGraphError.Create(SEMethodNotApplicable);
    end;
  CreateResidualNet(aGraph, aSource, aSink, aReqFlow);
  if not FindInitSolution then
    exit(0);
  Execute;
  Result := FResultFlow;
  aTotalCost := GetTotalCost;
end;

function TGCostedInt64Net.TCsMcfHelper.GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt;
  aReqFlow: TWeight; out aTotalCost: TCost; out a: TEdgeArray): TWeight;
begin
  if aReqFlow <= 0 then
    begin
      Result := 0;
      raise EGraphError.Create(SEMethodNotApplicable);
    end;
  CreateResidualNet(aGraph, aSource, aSink, aReqFlow);
  if not FindInitSolution then
    exit(0);
  Execute;
  Result := FResultFlow;
  a := CreateArcFlows(aTotalCost);
end;


