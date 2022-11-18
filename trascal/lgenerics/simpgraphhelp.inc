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

{ TGSimpleGraph.TNodeSearch }

function TGSimpleGraph.TNodeSearch.TimeOut: Boolean;
begin
  if not FCancelled then
    FCancelled := SecondsBetween(Now, FStartTime) >= FTimeOut;
  Result := FCancelled;
end;

{ TGSimpleGraph.TBPCliqueIsHelper }

procedure TGSimpleGraph.TBPCliqueIsHelper.GreedyColor(const aCand: TBoolVector; var aColOrd, aColors: TIntArray);
var
  P, Q: TBoolVector;
  I, J, ColorClass, PCount: SizeInt;
begin
  P := aCand;
  ColorClass := 0;
  I := 0;
  PCount := P.PopCount;
  while PCount > 0 do
    begin
      Inc(ColorClass);
      Q := P;
      while Q.NonEmpty do
        begin
          J := Q.Bsf;
          P.UncBits[J] := False;
          Q.UncBits[J] := False;
          Q.Subtract(FMatrix[J]);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
          Dec(PCount);
        end;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.Extend(var aCand: TBoolVector);
var
  NewCand: TBoolVector;
  ColOrd, Colors: TIntArray;
  I, J, CandCount: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if TimeOut then
        exit;
      CandCount := aCand.PopCount;
      ColOrd.Length := CandCount;
      Colors.Length := CandCount;
      GreedyColor(aCand, ColOrd, Colors);
      for I := Pred(CandCount) downto 0 do
        begin
          if Colors[I] + FCurrCount <= FRecentBest.Length then
            exit;
          J := ColOrd[I];
          aCand.UncBits[J] := False;
          FCurrSet.UncBits[FNodes[J]] := True;
          NewCand := aCand.Intersection(FMatrix[J]);
          Inc(FCurrCount);
          Extend(NewCand);
          if FCancelled then
            break;
          FCurrSet.UncBits[FNodes[J]] := False;
          Dec(FCurrCount);
        end;
    end
  else
    if FCurrSet.PopCount > FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.Extend(var aSub, aCand: TBoolVector);
var
  NewSub, NewCand: TBoolVector;
  I: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub.Bsf]) do
          begin
            aCand.UncBits[I] := False;
            NewCand := aCand.Intersection(FMatrix[I]);
            NewSub := aSub.Intersection(FMatrix[I]);
            FCurrSet.UncBits[FNodes[I]] := True;
            Extend(NewSub, NewCand);
            if FCancelled then
              break;
            FCurrSet.UncBits[FNodes[I]] := False;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCancelled);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
var
  Idx2Ord: TIntArray = nil;
  I: SizeInt;
  p: PAdjItem;
begin
  Idx2Ord.Length := FNodes.Length;
  for I := 0 to System.High(FNodes) do
    Idx2Ord[FNodes[I]] := I;
  System.SetLength(FMatrix, aGraph.VertexCount);
  if aComplement then
    for I := 0 to Pred(aGraph.VertexCount) do
      begin
        FMatrix[I].InitRange(aGraph.VertexCount);
        FMatrix[I].UncBits[I] := False;
        for p in aGraph.AdjLists[FNodes[I]]^ do
          FMatrix[I].UncBits[Idx2Ord[p^.Key]] := False;
      end
  else
    for I := 0 to Pred(aGraph.VertexCount) do
      begin
        FMatrix[I].Capacity := aGraph.VertexCount;
        for p in aGraph.AdjLists[FNodes[I]]^ do
          FMatrix[I].UncBits[Idx2Ord[p^.Key]] := True;
      end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FNodes := aGraph.SortComplementByWidth
  else
    FNodes := aGraph.SortNodesByWidth(soDesc);
  FillMatrix(aGraph, aComplement);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FNodes := aGraph.SortNodesByDegree(soAsc)
  else
    FNodes := aGraph.SortNodesByDegree(soDesc);
  FillMatrix(aGraph, aComplement);
end;

function TGSimpleGraph.TBPCliqueIsHelper.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBoolVector;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  SortMatrixByWidth(aGraph, False);
  //SortMatrixByDegree(aGraph, False);
  FRecentBest := aGraph.GreedyMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Capacity := aGraph.VertexCount;
  FCurrCount := 0;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCancelled;
end;

function TGSimpleGraph.TBPCliqueIsHelper.MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBoolVector;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  SortMatrixByWidth(aGraph, True);
  FRecentBest := aGraph.GreedyMIS;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Capacity := aGraph.VertexCount;
  FCurrCount := 0;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCancelled;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
var
  Sub, Cand: TBoolVector;
begin
  SortMatrixByDegree(aGraph, False);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Capacity := aGraph.VertexCount;
  FOnFind := aOnFind;
  FCancelled := False;
  Extend(Sub, Cand);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.ListMIS(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
var
  Sub, Cand: TBoolVector;
begin
  SortMatrixByDegree(aGraph, True);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Capacity := aGraph.VertexCount;
  FOnFind := aOnFind;
  FCancelled := False;
  Extend(Sub, Cand);
end;

{ TGSimpleGraph.TBPCliqueIsHelper256 }

procedure TGSimpleGraph.TBPCliqueIsHelper256.GreedyColor(const aCand: TBits256; var aColOrd, aColors: TIntArray);
var
  P, Q: TBits256;
  I, J, ColorClass, PCount: SizeInt;
begin
  P := aCand;
  ColorClass := 0;
  I := 0;
  PCount := P.PopCount;
  while PCount > 0 do
    begin
      Inc(ColorClass);
      Q := P;
      while Q.NonEmpty do
        begin
          J := Q.Bsf;
          P[J] := False;
          Q[J] := False;
          Q.Subtract(FMatrix[J]);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
          Dec(PCount);
        end;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.Extend(var aCand: TBits256);
var
  NewCand: TBits256;
  ColOrd, Colors: TIntArray;
  I, J, CandCount: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if TimeOut then
        exit;
      CandCount := aCand.PopCount;
      ColOrd.Length := CandCount;
      Colors.Length := CandCount;
      GreedyColor(aCand, ColOrd, Colors);
      for I := Pred(CandCount) downto 0 do
        begin
          if Colors[I] + FCurrCount <= FRecentBest.Length then
            exit;
          J := ColOrd[I];
          aCand[J] := False;
          FCurrSet[FNodes[J]] := True;
          NewCand := aCand.Intersection(FMatrix[J]);
          Inc(FCurrCount);
          Extend(NewCand);
          if FCancelled then
            break;
          FCurrSet[FNodes[J]] := False;
          Dec(FCurrCount);
        end;
    end
  else
    if FCurrSet.PopCount > FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.Extend(var aSub, aCand: TBits256);
var
  NewSub, NewCand: TBits256;
  I: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub.Bsf]) do
          begin
            aCand[I] := False;
            NewCand := aCand.Intersection(FMatrix[I]);
            NewSub := aSub.Intersection(FMatrix[I]);
            FCurrSet[FNodes[I]] := True;
            Extend(NewSub, NewCand);
            if FCancelled then
              break;
            FCurrSet[FNodes[I]] := False;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCancelled);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
var
  Idx2Ord: TIntArray = nil;
  I: SizeInt;
  p: PAdjItem;
begin
  Idx2Ord.Length := FNodes.Length;
  for I := 0 to System.High(FNodes) do
    Idx2Ord[FNodes[I]] := I;
  System.SetLength(FMatrix, aGraph.VertexCount);
  if aComplement then
    for I := 0 to Pred(aGraph.VertexCount) do
      begin
        FMatrix[I].InitRange(aGraph.VertexCount);
        FMatrix[I][I] := False;
        for p in aGraph.AdjLists[FNodes[I]]^ do
          FMatrix[I][Idx2Ord[p^.Key]] := False;
      end
  else
    for I := 0 to Pred(aGraph.VertexCount) do
      begin
        FMatrix[I].InitZero;
        for p in aGraph.AdjLists[FNodes[I]]^ do
          FMatrix[I][Idx2Ord[p^.Key]] := True;
      end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FNodes := aGraph.SortComplementByWidth
  else
    FNodes := aGraph.SortNodesByWidth(soDesc);
  FillMatrix(aGraph, aComplement);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FNodes := aGraph.SortNodesByDegree(soAsc)
  else
    FNodes := aGraph.SortNodesByDegree(soDesc);
  FillMatrix(aGraph, aComplement);
end;

function TGSimpleGraph.TBPCliqueIsHelper256.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBits256;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  SortMatrixByWidth(aGraph, False);
  FRecentBest := aGraph.GreedyMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FCurrCount := 0;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCancelled;
end;

function TGSimpleGraph.TBPCliqueIsHelper256.MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBits256;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  SortMatrixByWidth(aGraph, True);
  FRecentBest := aGraph.GreedyMIS;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FCurrCount := 0;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCancelled;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
var
  Sub, Cand: TBits256;
begin
  SortMatrixByDegree(aGraph, False);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FOnFind := aOnFind;
  FCancelled := False;
  Extend(Sub, Cand);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.ListMIS(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
var
  Sub, Cand: TBits256;
begin
  SortMatrixByDegree(aGraph, True);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FOnFind := aOnFind;
  FCancelled := False;
  Extend(Sub, Cand);
end;

{ TGSimpleGraph.TMvcHelper }

procedure TGSimpleGraph.TMvcHelper.SetFound(const aSet: TIntArray; var aCancel: Boolean);
var
  Mvc: TIntArray;
  I: SizeInt;
begin
  FVertexSet.InitRange(FNodeCount);
  for I in aSet do
    FVertexSet.UncBits[I] := False;
  Mvc := FVertexSet.ToArray;
  if not Mvc.IsEmpty then
    FOnFind(Mvc, aCancel)
end;

procedure TGSimpleGraph.TMvcHelper.Init(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
begin
  FNodeCount := aGraph.VertexCount;
  FOnFind := aOnFind;
end;

procedure TGSimpleGraph.TCliqueHelper.GreedyColor(const aCand: TIntSet; var aColOrd, aColors: TIntArray);
var
  P, Q: TIntSet;
  I, J, ColorClass: SizeInt;
begin
  P.Assign(aCand);
  P.Reverse;
  ColorClass := 0;
  I := 0;
  while P.NonEmpty do
    begin
      Inc(ColorClass);
      Q.Assign(P);
      while Q.NonEmpty do
        begin
          J := Q.Pop;
          P.Delete(J);
          Q.Subtract(FMatrix[J]^);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
        end;
    end;
end;

procedure TGSimpleGraph.TCliqueHelper.Extend(var aCand: TIntSet);
var
  NewCand: TIntSet;
  ColOrd, Colors: TIntArray;
  I, J: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if TimeOut then
        exit;
      ColOrd.Length := aCand.Count;
      Colors.Length := aCand.Count;
      GreedyColor(aCand, ColOrd, Colors);
      for I := Pred(aCand.Count) downto 0 do
        begin
          if Colors[I] + FCurrSet.Count <= FRecentBest.Length then
            exit;
          J := ColOrd[I];
          aCand.Delete(J);
          FCurrSet.Push(FNodes[J]);
          NewCand := aCand.Intersection(FMatrix[J]^);
          Extend(NewCand);
          if FCancelled then
            break;
          FCurrSet.Pop;
        end;
    end
  else
    if FCurrSet.Count > FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TCliqueHelper.Extend(var aSub, aCand: TIntSet);
var
  NewSub, NewCand: TIntSet;
  I: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub[0]]^) do
          begin
            aCand.Delete(I);
            NewCand := aCand.Intersection(FMatrix[I]^);
            NewSub := aSub.Intersection(FMatrix[I]^);
            FCurrSet.Push(FNodes[I]);
            Extend(NewSub, NewCand);
            if FCancelled then
              break;
            FCurrSet.Pop;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCancelled);
end;

function TGSimpleGraph.TCliqueHelper.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TIntSet;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  FNodes := aGraph.SortNodesByWidth(soDesc);
  FMatrix := aGraph.CreateSkeleton;
  FRecentBest := aGraph.GreedyMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCancelled;
end;

procedure TGSimpleGraph.TCliqueHelper.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
var
  Sub, Cand: TIntSet;
begin
  FNodes := aGraph.SortNodesByDegree(soDesc);
  FMatrix := aGraph.CreateSkeleton;
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FOnFind := aOnFind;
  FCancelled := False;
  Extend(Sub, Cand);
end;

{ TGSimpleGraph.TBPDomSetHelper }

procedure TGSimpleGraph.TBPDomSetHelper.FillMatrix(aGraph: TGSimpleGraph; out aCand: TBoolVector);
var
  Idx2Ord: TIntArray = nil;
  I, Degree: SizeInt;
  p: PAdjItem;
begin
  FNodes := aGraph.SortNodesByDegree(soDesc);
  Idx2Ord.Length := FNodes.Length;
  for I := 0 to System.High(FNodes) do
    Idx2Ord[FNodes[I]] := I;
  System.SetLength(FMatrix, System.Length(FNodes));
  aCand.InitRange(FNodes.Length);
  FCurrSet.Capacity := FNodes.Length;
  for I := 0 to System.High(FNodes) do
    begin
      FMatrix[I].Capacity := FNodes.Length;
      Degree := 0;
      for p in aGraph.AdjLists[FNodes[I]]^ do
        begin
          FMatrix[I].UncBits[Idx2Ord[p^.Key]] := True;
          Inc(Degree);
        end;
      if Degree = 0 then
        begin
          FCurrSet.UncBits[FNodes[I]] := True;
          aCand.UncBits[I] := False;
        end;
    end;
end;

procedure TGSimpleGraph.TBPDomSetHelper.Extend(const aCand, aTested: TBoolVector);
var
  NewCand, NewTested: TBoolVector;
  I, J: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if FCurrCount >= FRecentBest.Length - 1 then
        exit;
      if TimeOut then
        exit;
      I := NULL_INDEX;
      for J in aCand do
        if not aTested.UncBits[J] then
          begin
            I := J;
            break;
          end;
      if I = NULL_INDEX then
        exit;
      NewTested := aTested;
      NewTested.UncBits[I] := True;
      NewCand := aCand.Difference(FMatrix[I]);
      NewCand.UncBits[I] := False;
      FCurrSet.UncBits[FNodes[I]] := True;
      Inc(FCurrCount);
      Extend(NewCand, NewTested);
      FCurrSet.UncBits[FNodes[I]] := False;
      Dec(FCurrCount);
      if (FCurrCount < Pred(FRecentBest.Length)) and not FCancelled then
        for J in aCand.Intersection(FMatrix[I]) do
          begin
            if NewTested.UncBits[J] then
              continue;
            NewTested.UncBits[J] := True;
            NewCand := aCand.Difference(FMatrix[J]);
            NewCand.UncBits[J] := False;
            FCurrSet.UncBits[FNodes[J]] := True;
            Inc(FCurrCount);
            Extend(NewCand, NewTested);
            if (FCurrCount < Pred(FRecentBest.Length)) and not FCancelled then
              begin
                NewCand.Subtract(FMatrix[I]);
                FCurrSet.UncBits[FNodes[I]] := True;
                Inc(FCurrCount);
                Extend(NewCand, NewTested);
                FCurrSet.UncBits[FNodes[I]] := False;
                Dec(FCurrCount);
              end;
            if (FCurrCount >= FRecentBest.Length) or FCancelled then
              break;
            FCurrSet.UncBits[FNodes[J]] := False;
            Dec(FCurrCount);
          end;
    end
  else
    if FCurrSet.PopCount < FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

function TGSimpleGraph.TBPDomSetHelper.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand, Tested: TBoolVector;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  FillMatrix(aGraph, Cand);
  FRecentBest := aGraph.GreedyMDS;
  Tested.Capacity := aGraph.VertexCount;
  FCurrCount := 0;
  Extend(Cand, Tested);
  aExact := not FCancelled;
  Result := FRecentBest;
end;

{ TGSimpleGraph.TBPDomSetHelper256 }

procedure TGSimpleGraph.TBPDomSetHelper256.FillMatrix(aGraph: TGSimpleGraph; out aCand: TBits256);
var
  Idx2Ord: TIntArray = nil;
  I, Degree: SizeInt;
  p: PAdjItem;
begin
  FNodes := aGraph.SortNodesByDegree(soDesc);
  Idx2Ord.Length := FNodes.Length;
  for I := 0 to System.High(FNodes) do
    Idx2Ord[FNodes[I]] := I;
  System.SetLength(FMatrix, System.Length(FNodes));
  aCand.InitRange(FNodes.Length);
  FCurrSet.InitZero;
  for I := 0 to System.High(FNodes) do
    begin
      FMatrix[I].InitZero;
      Degree := 0;
      for p in aGraph.AdjLists[FNodes[I]]^ do
        begin
          FMatrix[I][Idx2Ord[p^.Key]] := True;
          Inc(Degree);
        end;
      if Degree = 0 then
        begin
          FCurrSet[FNodes[I]] := True;
          aCand[I] := False;
        end;
    end;
end;

procedure TGSimpleGraph.TBPDomSetHelper256.Extend(const aCand, aTested: TBits256);
var
  NewCand, NewTested: TBits256;
  I, J: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if FCurrCount >= FRecentBest.Length - 1 then
        exit;
      if TimeOut then
        exit;
      I := NULL_INDEX;
      for J in aCand do
        if not aTested[J] then
          begin
            I := J;
            break;
          end;
      if I = NULL_INDEX then
        exit;
      NewTested := aTested;
      NewTested[I] := True;
      NewCand := aCand.Difference(FMatrix[I]);
      NewCand[I] := False;
      FCurrSet[FNodes[I]] := True;
      Inc(FCurrCount);
      Extend(NewCand, NewTested);
      FCurrSet[FNodes[I]] := False;
      Dec(FCurrCount);
      if (FCurrCount < Pred(FRecentBest.Length)) and not FCancelled then
        for J in aCand.Intersection(FMatrix[I]) do
          begin
            if NewTested[J] then
              continue;
            NewTested[J] := True;
            NewCand := aCand.Difference(FMatrix[J]);
            NewCand[J] := False;
            FCurrSet[FNodes[J]] := True;
            Inc(FCurrCount);
            Extend(NewCand, NewTested);
            if (FCurrCount < Pred(FRecentBest.Length)) and not FCancelled then
              begin
                NewCand.Subtract(FMatrix[I]);
                FCurrSet[FNodes[I]] := True;
                Inc(FCurrCount);
                Extend(NewCand, NewTested);
                FCurrSet[FNodes[I]] := False;
                Dec(FCurrCount);
              end;
            if (FCurrCount >= FRecentBest.Length) or FCancelled then
              break;
            FCurrSet[FNodes[J]] := False;
            Dec(FCurrCount);
          end;
    end
  else
    if FCurrSet.PopCount < FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

function TGSimpleGraph.TBPDomSetHelper256.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand, Tested: TBits256;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  FillMatrix(aGraph, Cand);
  FRecentBest := aGraph.GreedyMDS;
  {%H-}Tested.InitZero;
  FCurrCount := 0;
  Extend(Cand, Tested);
  aExact := not FCancelled;
  Result := FRecentBest;
end;

{ TGSimpleGraph.TDomSetHelper }

procedure TGSimpleGraph.TDomSetHelper.Extend(const aCand: TIntSet);
var
  NewCand: TIntSet;
  I, J: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if FCurrSet.Count >= FRecentBest.Length - 1 then
        exit;
      if TimeOut then
        exit;
      I := aCand[0];
      NewCand.Assign(aCand);
      FCurrSet.Push(I);
      NewCand := aCand.Difference(FMatrix[I]^);
      NewCand.Delete(I);
      Extend(NewCand);
      FCurrSet.Pop;
      if (FCurrSet.Count >= FRecentBest.Length - 1) or FCancelled then
        exit;
      for J in aCand.Intersection(FMatrix[I]^) do
        begin
          FCurrSet.Push(J);
          NewCand := aCand.Difference(FMatrix[J]^);
          NewCand.Delete(J);
          Extend(NewCand);
          if (FCurrSet.Count < FRecentBest.Length - 1) and not FCancelled then
            begin
              FCurrSet.Push(I);
              NewCand.Subtract(FMatrix[I]^);
              Extend(NewCand);
              FCurrSet.Pop;
            end;
          if (FCurrSet.Count >= FRecentBest.Length) or FCancelled then
            exit;
          FCurrSet.Pop;
        end;
    end
  else
    if aCand.Count < FRecentBest.Length then
      FRecentBest := FCurrSet.ToArray;
end;

function TGSimpleGraph.TDomSetHelper.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TIntSet;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FCancelled := False;
  FStartTime := Now;
  FRecentBest := aGraph.GreedyMDS;
  FMatrix := aGraph.CreateSkeleton;
  Cand.AssignArray(aGraph.SortNodesByDegree(soDesc));
  while Cand.NonEmpty and FMatrix[Cand.Last]^.IsEmpty do
    FCurrSet.Push(Cand.Pop);
  Extend(Cand);
  aExact := not FCancelled;
  Result := FRecentBest;
end;

{ TGSimpleGraph.TExactColor.TNode }

constructor TGSimpleGraph.TExactColor.TNode.Create(aDegree, aUpperBound: SizeInt; aEdgeList: PLink);
begin
  Degree := aDegree;
  Saturation := 0;
  NeighbCount := aDegree;
  EdgeList := aEdgeList;
  System.SetLength(AdjColors, aUpperBound);
  System.FillChar(Pointer(AdjColors)^, aUpperBound * SizeOf(Integer), 0);
end;

procedure TGSimpleGraph.TExactColor.TNode.NeighbPickColor(aColor: Integer);
begin
  Saturation += Ord(AdjColors[Pred(aColor)] = 0);
  Inc(AdjColors[Pred(aColor)]);
  Dec(Degree);
end;

procedure TGSimpleGraph.TExactColor.TNode.NeighbDropColor(aColor: Integer);
begin
  Dec(AdjColors[Pred(aColor)]);
  Saturation -= Ord(AdjColors[Pred(aColor)] = 0);
  Inc(Degree);
end;

{ TGSimpleGraph.TExactColor }

procedure TGSimpleGraph.TExactColor.CreateStaticGraph;
var
  I, J: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FNodes, FNodeCount);
  System.SetLength(FEdgeList, FGraph.EdgeCount * 2);
  J := 0;
  for I := 0 to System.High(FNodes) do
    begin
      FNodes[I] := TNode.Create(FGraph.AdjLists[I]^.Count, Pred(FUpBound), @FEdgeList[J]);
      for p in FGraph.AdjLists[I]^ do
        begin
          FEdgeList[J] := @FNodes[p^.Key];
          Inc(J);
        end;
    end;
end;

function TGSimpleGraph.TExactColor.InitLowBound: SizeInt;
var
  Clique: TIntArray;
  I, J: SizeInt;
  Exact: Boolean;
begin
  Clique := FGraph.FindMaxClique(Exact, FTimeOut - SecondsBetween(Now, FStartTime));
  Result := Clique.Length;
  FCancelled := not Exact;
  if FCancelled or (Result >= FUpBound) then
    exit;
  CreateStaticGraph;
  FColorMap := FGraph.CreateIntArray(0);
  FAchromatic.InitRange(FNodeCount);
  J := 1;
  for I in Clique do
    begin
      FAchromatic.UncBits[I] := False;
      PickColor(I, J);
      Inc(J);
    end;
end;

procedure TGSimpleGraph.TExactColor.InitComplete;
var
  I: SizeInt;
begin
  CreateStaticGraph;
  FAchromatic.InitRange(FNodeCount);
  for I := 0 to System.High(FColorMap) do
    if FColorMap[I] > 0 then
      begin
        FAchromatic.UncBits[I] := False;
        PickColor(I, FColorMap[I]);
      end;
end;

function TGSimpleGraph.TExactColor.PickColor(aIndex, aColor: SizeInt): Boolean;
var
  I: SizeInt;
begin
  Result := FNodes[aIndex].AdjColors[Pred(aColor)] = 0;
  if Result then
    begin
      FColorMap[aIndex] := aColor;
      with FNodes[aIndex] do
        for I := 0 to Pred(NeighbCount) do
          EdgeList[I]^.NeighbPickColor(aColor);
    end;
end;

procedure TGSimpleGraph.TExactColor.DropColor(aIndex, aColor: SizeInt);
var
  I: SizeInt;
begin
  FColorMap[aIndex] := 0;
  with FNodes[aIndex] do
    for I := 0 to Pred(NeighbCount) do
      EdgeList[I]^.NeighbDropColor(aColor);
end;

function TGSimpleGraph.TExactColor.SelectNext(out aNode: SizeInt): Boolean;
var
  I, MaxSat: Integer;
begin
  MaxSat := NULL_INDEX;
  aNode := NULL_INDEX;
  for I in FAchromatic do
    with FNodes[I] do
      if (Saturation > MaxSat) or (Saturation = MaxSat) and (Degree > FNodes[aNode].Degree) then
        begin
          MaxSat := Saturation;
          aNode := I;
        end;
  Result := aNode >= 0;
end;

procedure TGSimpleGraph.TExactColor.DSatur(aMaxColor: SizeInt);
var
  CurrNode, Color: SizeInt;
begin
  if TimeOut or (aMaxColor >= FUpBound) or (FUpBound <= FLowBound) then
    exit;
  if not SelectNext(CurrNode) then
    begin
      if aMaxColor < FUpBound then
        begin
          FUpBound := aMaxColor;
          FRecentBest := System.Copy(FColorMap);
        end;
      exit;
    end;
  FAchromatic.UncBits[CurrNode] := False;
  for Color := 1 to aMaxColor do
    if PickColor(CurrNode, Color) then
      begin
        DSatur(aMaxColor);
        DropColor(CurrNode, Color);
        if aMaxColor >= FUpBound  then
          break;
      end;
  if (aMaxColor < Pred(FUpBound)) and PickColor(CurrNode, Succ(aMaxColor)) then
    begin
      DSatur(Succ(aMaxColor));
      DropColor(CurrNode, Succ(aMaxColor));
    end;
  FAchromatic.UncBits[CurrNode] := True;
end;

function TGSimpleGraph.TExactColor.Colorize(aGraph: TGSimpleGraph; aTimeOut: Integer; out aColors: TIntArray;
  out aExact: Boolean): SizeInt;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FNodeCount := aGraph.VertexCount;
  FGraph := aGraph;
  FCancelled := False;
  FStartTime := Now;
  FUpBound := FGraph.GreedyColorRlf(FRecentBest);
  FLowBound := InitLowBound;
  if not FCancelled and (FLowBound < FUpBound) then
    DSatur(FLowBound);
  aExact := not FCancelled;
  Result := FUpBound;
  aColors := FRecentBest;
end;

function TGSimpleGraph.TExactColor.IsColorable(aGraph: TGSimpleGraph; aK: SizeInt; aTimeOut: Integer;
  out aColors: TIntArray): TTriLean;
var
  Lb: SizeInt;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FNodeCount := aGraph.VertexCount;
  FGraph := aGraph;
  FLowBound := aK;
  FUpBound := Succ(aK);
  FCancelled := False;
  FStartTime := Now;
  Lb := InitLowBound;
  if (Lb < FUpBound) and not FCancelled then
    DSatur(Lb);
  if FLowBound >= FUpBound then
    begin
      aColors := FRecentBest;
      Result := tlTrue;
    end
  else
    if not FCancelled then
      Result := tlFalse
    else
      Result := tlUnknown;
end;

function TGSimpleGraph.TExactColor.Complete(aGraph: TGSimpleGraph; aK: SizeInt; aTimeOut: Integer;
  var aColors: TIntArray): TTriLean;
begin
  FTimeOut := aTimeOut and System.High(Integer);
  FNodeCount := aGraph.VertexCount;
  FGraph := aGraph;
  FLowBound := aK;
  FUpBound := Succ(aK);
  FCancelled := False;
  FStartTime := Now;
  FColorMap := System.Copy(aColors);
  InitComplete;
  DSatur(FLowBound);
  if FLowBound >= FUpBound then
    begin
      aColors := FRecentBest;
      Result := tlTrue;
    end
  else
    if not FCancelled then
      Result := tlFalse
    else
      Result := tlUnknown;
end;

{ TGSimpleGraph.TGreedyColorRlf.TNode }

class operator TGSimpleGraph.TGreedyColorRlf.TNode.<(const L, R: TNode): Boolean;
begin
  if L.WDegree <> R.WDegree then
    Result := L.WDegree < R.WDegree
  else
    if L.Degree <> R.Degree then
      Result := L.Degree < R.Degree
    else
      Result := L.Index < R.Index;
end;

constructor TGSimpleGraph.TGreedyColorRlf.TNode.Create(aIndex, aDegree: SizeInt);
begin
  Index := aIndex;
  WDegree := 0;
  Degree := aDegree;
end;

{ TGSimpleGraph.TGreedyColorRlf }

function TGSimpleGraph.TGreedyColorRlf.Execute(aGraph: TGSimpleGraph; out aColors: TIntArray): SizeInt;
var
  Nodes: array of TNode;
  Queue: TQueue;
  Achromatic, CurrIS, InQueue: TBoolVector;
  CurrNode, NextNode: TNode;
  I: SizeInt;
  p, pAdj: PAdjItem;
begin
  System.SetLength(Nodes, aGraph.VertexCount);
  for I := 0 to System.High(Nodes) do
    Nodes[I] := TNode.Create(I, aGraph.AdjLists[I]^.Count);
  aColors.Length := aGraph.VertexCount;
  Achromatic.InitRange(aGraph.VertexCount);
  InQueue.Capacity := aGraph.VertexCount;
  Queue := TQueue.Create(aGraph.VertexCount);
  Result := 0;
  while Achromatic.NonEmpty do
    begin
      Inc(Result);
      CurrIS := Achromatic;
      InQueue := Achromatic;
      for I in Achromatic do
        Queue.Enqueue(I, Nodes[I]);
      while Queue.TryDequeue(CurrNode) do
        begin
          InQueue.UncBits[CurrNode.Index] := False;
          if CurrIS.UncBits[CurrNode.Index] then
            begin
              CurrIS.UncBits[CurrNode.Index] := False;
              Achromatic.UncBits[CurrNode.Index] := False;
              aColors[CurrNode.Index] := Result;
              for p in aGraph.AdjLists[CurrNode.Index]^ do
                if Achromatic.UncBits[p^.Key] then
                  begin
                    Dec(Nodes[p^.Key].Degree);
                    CurrIS.UncBits[p^.Key] := False;
                    for pAdj in aGraph.AdjLists[p^.Key]^ do
                      if InQueue.UncBits[pAdj^.Key] then
                        begin
                          NextNode := Queue.GetItem(pAdj^.Key);
                          Inc(NextNode.WDegree);
                          Queue.Update(pAdj^.Key, NextNode);
                        end;
                  end;
            end;
        end;
    end;
end;

{ TGSimpleGraph.THamiltonSearch }

procedure TGSimpleGraph.THamiltonSearch.Init(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector);
begin
  FSource := aSrc;
  if aCount <= 0 then
    FRequired := High(SizeInt)
  else
    FRequired := aCount;
  FPaths := pv;
  FNodeCount := aGraph.VertexCount;
  FStack := TSimpleStack.Create(Succ(FNodeCount));
  FMatrix := aGraph.CreateBoolMatrix;
  FVacant.InitRange(FNodeCount);
  FTimeOut := aTimeOut and System.High(Integer);
  FFound := 0;
  FDone := False;
  FCancelled := False;
  FStartTime := Now;
end;

function TGSimpleGraph.THamiltonSearch.TimeToFinish: Boolean;
begin
  FCancelled := FCancelled or (SecondsBetween(Now, FStartTime) >= FTimeOut);
  Result := FCancelled or FDone;
end;

function TGSimpleGraph.THamiltonSearch.SelectMin(const v: TBoolVector; out aValue: SizeInt): Boolean;
var
  I, Degree, MinDegree: SizeInt;
begin
  MinDegree := FNodeCount;
  aValue := NULL_INDEX;
  for I in v do
    begin
      Degree := FMatrix[I].PopCount;
      if Degree < MinDegree then
        begin
          MinDegree := Degree;
          aValue := I;
        end;
    end;
  Result := aValue <> NULL_INDEX;
end;

procedure TGSimpleGraph.THamiltonSearch.CheckIsCycle(aNode: SizeInt);
begin
  if FMatrix[aNode].UncBits[FSource] then
    begin
      FStack.Push(FSource);
      FPaths^.Add(FStack.ToArray);
      Inc(FFound);
      FStack.Pop;
      FDone := FDone or (FFound >= FRequired);
    end;
end;

procedure TGSimpleGraph.THamiltonSearch.CheckIsPath(aNode: SizeInt);
begin
  Assert(aNode = aNode); //to supress hints
  FPaths^.Add(FStack.ToArray);
  Inc(FFound);
  FDone := FDone or (FFound >= FRequired);
end;

procedure TGSimpleGraph.THamiltonSearch.SearchFor(aNode: SizeInt);
var
  Cand, Saved: TBoolVector;
  I: SizeInt;
begin
  if FVacant.NonEmpty then
    begin
      for I in FVacant do
        if FMatrix[I].IsEmpty then
          exit;
      if FMatrix[aNode].Intersecting(FVacant) then
        begin
          Cand := FMatrix[aNode].Intersection(FVacant);
          Saved.Capacity := FNodeCount;
          for I in Cand do
            begin
              Saved.UncBits[I] := FMatrix[I].UncBits[aNode];
              FMatrix[I].UncBits[aNode] := False;
            end;
          /////////////////////////////
          while SelectMin(Cand, I) do
            begin
              Cand.UncBits[I] := False;
              FStack.Push(I);
              FVacant.UncBits[I] := False;
              SearchFor(I);
              if TimeToFinish then
                exit;
              FVacant.UncBits[I] := True;
              FStack.Pop;
            end;
          /////////////////////////////
          for I in Saved do
            FMatrix[I].UncBits[aNode] := True;
        end;
    end
  else
    FOnCheckNode(aNode);
end;

procedure TGSimpleGraph.THamiltonSearch.ExecuteCycles;
var
  I: SizeInt;
begin
  FVacant.UncBits[FSource] := False;
  FStack.Push(FSource);
  FOnCheckNode := @CheckIsCycle;
  for I in FMatrix[FSource] do
    begin
      FStack.Push(I);
      FVacant.UncBits[I] := False;
      SearchFor(I);
      if TimeToFinish then
        break;
      FVacant.UncBits[I] := True;
      FStack.Pop;
      //FMatrix[I][FSource] := False;
    end;
end;

procedure TGSimpleGraph.THamiltonSearch.ExecutePaths;
var
  I: SizeInt;
begin
  FVacant.UncBits[FSource] := False;
  FStack.Push(FSource);
  FOnCheckNode := @CheckIsPath;
  for I in FMatrix[FSource] do
    begin
      FStack.Push(I);
      FVacant.UncBits[I] := False;
      SearchFor(I);
      if TimeToFinish then
        break;
      FVacant.UncBits[I] := True;
      FStack.Pop;
    end;
end;

function TGSimpleGraph.THamiltonSearch.FindCycles(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector): Boolean;
begin
  Init(aGraph, aSrc, aCount, aTimeOut, pv);
  ExecuteCycles;
  Result := not FCancelled and pv^.NonEmpty;
end;

function TGSimpleGraph.THamiltonSearch.FindPaths(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector): Boolean;
begin
  Init(aGraph, aSrc, aCount, aTimeOut, pv);
  ExecutePaths;
  Result := not FCancelled and pv^.NonEmpty;
end;

{ TGSimpleGraph.THKMatch }

procedure TGSimpleGraph.THKMatch.Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
var
  CurrArcIdx: TIntArray = nil;
  Grays: TIntHashSet;
  I, J: SizeInt;
  p: PAdjItem;
begin
  FNodeCount := Succ(aGraph.VertexCount);
  FDummy := Pred(FNodeCount);
  if System.Length(w) <= System.Length(g) then
    begin
      FWhites := w;
      Grays.AddAll(g);
    end
  else
    begin
      FWhites := g;
      Grays.AddAll(w);
    end;

  CurrArcIdx.Length := Succ(FNodeCount);
  J := 0;
  for I := 0 to FNodeCount - 2 do
    begin
      CurrArcIdx[I] := J;
      if Grays.Contains(I) then
        J += Succ(aGraph.DegreeI(I))
      else
        J += aGraph.DegreeI(I);
    end;
  CurrArcIdx[Pred(FNodeCount)] := J;

  System.SetLength(FNodes, Succ(FNodeCount));
  System.SetLength(FArcs, Succ((aGraph.EdgeCount + Grays.Count) * 2));

  for I := 0 to Pred(FNodeCount) do
    begin
      FNodes[I].FirstArc := CurrArcIdx[I];
      FNodes[I].Mate := FDummy;
    end;

  for I in FWhites do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        FArcs[CurrArcIdx[I]].Target := J;
        FArcs[CurrArcIdx[J]].Target := I;
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  J := FDummy;
  for I in Grays do
    begin
      FArcs[CurrArcIdx[I]].Target := J;
      FArcs[CurrArcIdx[J]].Target := I;
      Inc(CurrArcIdx[I]);
      Inc(CurrArcIdx[J]);
    end;

  CurrArcIdx := nil;

  FArcs[System.High(FArcs)].Target := FNodeCount;
  //sentinel node
  FNodes[FNodeCount].FirstArc := System.High(FArcs);
  FNodes[FNodeCount].Distance := INF_DIST;
  FNodes[FNodeCount].Mate := FDummy;

  FQueue := aGraph.CreateIntArray;
end;

function TGSimpleGraph.THKMatch.Bfs: Boolean;
var
  Curr, CurrArc, Matched, Dist: SizeInt;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  for Curr in FWhites do
    if FNodes[Curr].Mate = FDummy then
      begin
        FNodes[Curr].Distance := 0;
        FQueue[qTail] := Curr;
        Inc(qTail);
      end
    else
      FNodes[Curr].Distance := INF_DIST;

  FNodes[FDummy].Distance := INF_DIST;

  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      if FNodes[{%H-}Curr].Distance < FNodes[FDummy].Distance then
        begin
          CurrArc := FNodes[Curr].FirstArc;
          Dist := Succ(FNodes[Curr].Distance);
          while CurrArc < FNodes[Succ(Curr)].FirstArc do
            begin
              Matched := FNodes[FArcs[CurrArc].Target].Mate;
              if FNodes[Matched].Distance = INF_DIST then
                begin
                  FNodes[Matched].Distance := Dist;
                  FQueue[qTail] := Matched;
                  Inc(qTail);
                end;
              Inc(CurrArc);
            end;
        end;
    end;
  Result := FNodes[FDummy].Distance <> INF_DIST;
end;

function TGSimpleGraph.THKMatch.Dfs(aRoot: SizeInt): Boolean;
var
  CurrArc, Dist, Next, Mate: SizeInt;
begin
  //todo: non-recursive dfs ???
  if aRoot = FDummy then
    exit(True);
  CurrArc := FNodes[aRoot].FirstArc;
  Dist := Succ(FNodes[aRoot].Distance);
  while CurrArc < FNodes[Succ(aRoot)].FirstArc do
    begin
      Next := FArcs[CurrArc].Target;
      Mate := FNodes[Next].Mate;
      if (FNodes[Mate].Distance = Dist) and Dfs(Mate) then
        begin
          FNodes[aRoot].Mate := Next;
          FNodes[Next].Mate := aRoot;
          exit(True);
        end;
      Inc(CurrArc);
    end;
  FNodes[aRoot].Distance := INF_DIST;
  Result := False;
end;

function TGSimpleGraph.THKMatch.HopcroftKarp: TIntEdgeArray;
var
  I, J, Size: SizeInt;
begin
  Size := 0;
  while Bfs do
    for I in FWhites do
      if FNodes[I].Mate = FDummy then
        Size += Ord(Dfs(I));
  System.SetLength(Result, Size);
  J := 0;
  for I in FWhites do
    if FNodes[I].Mate <> FDummy then
      begin
        Result[J] := TIntEdge.Create(I, FNodes[I].Mate);
        Inc(J);
      end;
end;

function TGSimpleGraph.THKMatch.MaxMatching(aGraph: TGSimpleGraph; const w, g: TIntArray): TIntEdgeArray;
begin
  Init(aGraph, w, g);
  Result := HopcroftKarp;
end;

{ TGSimpleGraph.TBfsMatch }

procedure TGSimpleGraph.TBfsMatch.Match(aNode, aMate: SizeInt);
begin
  FMates[aNode] := aMate;
  FMates[aMate] := aNode;
end;

procedure TGSimpleGraph.TBfsMatch.Init(aGraph: TGSimpleGraph; const w, g: TIntArray);
var
  I: SizeInt;
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FWhites.Capacity := aGraph.VertexCount;
  FVisited.Capacity := aGraph.VertexCount;
  if System.Length(w) <= System.Length(g) then
    for I in w do
      FWhites.UncBits[I] := True
  else
    for I in g do
      FWhites.UncBits[I] := True;
  FMates := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  for e in aGraph.GreedyMatching do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TBfsMatch.FindAugmentPath(aRoot: SizeInt): SizeInt;
var
  Curr, Next: SizeInt;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FVisited.ClearBits;
  FParents[aRoot] := NULL_INDEX;
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      if FWhites.UncBits[Curr] then
        begin
          for p in FGraph.AdjLists[Curr]^ do
            begin
              Next := p^.Destination;
              if (FMates[Curr] = Next) or FVisited.UncBits[Next] then
                continue;
              if FMates[Next] = NULL_INDEX then
                begin
                  FParents[Next] := Curr;
                  exit(Next);
                end
              else
                begin
                  FParents[Next] := Curr;
                  FQueue[qTail] := Next;
                  Inc(qTail);
                end;
            end;
        end
      else
        begin
          Next := FMates[Curr];
          FParents[Next] := Curr;
          FQueue[qTail] := Next;
          Inc(qTail);
        end;
    end;
  Result := NULL_INDEX;
end;

procedure TGSimpleGraph.TBfsMatch.AlternatePath(aRoot: SizeInt);
var
  Mate, tmp: SizeInt;
begin
  repeat
    Mate := FParents[aRoot];
    tmp := FMates[Mate];
    Match(aRoot, Mate);
    aRoot := tmp;
  until aRoot = NULL_INDEX;
end;

procedure TGSimpleGraph.TBfsMatch.BfsMatch;
var
  I, Last: SizeInt;
begin
  for I in FWhites do
    if FMates[I] = NULL_INDEX then
      begin
        Last := FindAugmentPath(I);
        if Last <> NULL_INDEX then
          begin
            AlternatePath(Last);
            Inc(FMatchCount);
          end;
      end;
end;

function TGSimpleGraph.TBfsMatch.CreateEdges: TIntEdgeArray;
var
  I, J: SizeInt;
begin
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I in FWhites do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        Inc(J);
      end;
end;

function TGSimpleGraph.TBfsMatch.MaxMatching(aGraph: TGSimpleGraph; const w, g: TIntArray): TIntEdgeArray;
begin
  Init(aGraph, w, g);
  BfsMatch;
  Result := CreateEdges;
end;

{ TGSimpleGraph.TEdMatchHelper }

procedure TGSimpleGraph.TEdMatchHelper.Match(aNode, aMate: SizeInt);
begin
  FMates[aNode] := aMate;
  FMates[aMate] := aNode;
end;

procedure TGSimpleGraph.TEdMatchHelper.ClearBase;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBase) do
   FBase[I] := I;
end;

procedure TGSimpleGraph.TEdMatchHelper.ClearParents;
begin
  System.FillChar(Pointer(FParents)^, System.Length(FParents) * SizeOf(SizeInt), $ff);
end;

function TGSimpleGraph.TEdMatchHelper.Lca(L, R: SizeInt): SizeInt;
begin
  FLcaUsed.ClearBits;
  repeat
    L := FBase[L];
    FLcaUsed.UncBits[L] := True;
    if FMates[L] = NULL_INDEX then
        break;
    L := FParents[FMates[L]];
  until False;
  repeat
    R := FBase[R];
    if FLcaUsed.UncBits[R] then
      exit(R);
     R := FParents[FMates[R]];
  until False;
  Result := NULL_INDEX;
end;

procedure TGSimpleGraph.TEdMatchHelper.MarkPath(aNode, aBloss, aChild: SizeInt);
begin
  while FBase[aBloss] <> aBloss do
    begin
      FBlossoms.UncBits[FBase[aNode]] := True;
      FBlossoms.UncBits[FBase[FMates[aNode]]] := True;
      FParents[aNode] := aChild;
      aChild := FMates[aNode];
      aNode := FParents[FMates[aNode]];
    end;
end;

function TGSimpleGraph.TEdMatchHelper.FindAugmentPath(aRoot: SizeInt; out aLast: SizeInt): Boolean;
var
  I, Curr, Next, CurrBase: SizeInt;
  p: TGSimpleGraph.PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FVisited.ClearBits;
  ClearParents;
  ClearBase;
  FVisited.UncBits[aRoot] := True;
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      for p in FGraph.AdjLists[Curr]^ do
        begin
          Next := p^.Destination;
          if (FBase[Curr] = FBase[Next]) or (FMates[Curr] = Next) then
            continue;
          if (Next = aRoot) or (FMates[Next] <> NULL_INDEX) and (FParents[FMates[Next]] <> NULL_INDEX) then
            begin
              CurrBase := Lca(Curr, Next);
              FBlossoms.ClearBits;
      	      MarkPath(Curr, CurrBase, Next);
      	      MarkPath(Next, CurrBase, Curr);
              for I := 0 to System.High(FBase) do
                if FBlossoms.UncBits[FBase[I]] then
                  begin
                    FBase[I] := CurrBase;
                    if not FVisited.UncBits[I] then
                      begin
                        FVisited.UncBits[I] := True;
                        FQueue[qTail] := I;
                        Inc(qTail);
                      end;
                  end;
            end
          else
            if FParents[Next] = NULL_INDEX then
              begin
                FParents[Next] := Curr;
                if FMates[Next] = NULL_INDEX then
                  begin
                    aLast := Next;
                    exit(True);
                  end;
                Next := FMates[Next];
                FVisited.UncBits[Next] := True;
                FQueue[qTail] := Next;
                Inc(qTail);
              end;
        end;
    end;
  Result := False;
end;

procedure TGSimpleGraph.TEdMatchHelper.AlternatePath(aRoot: SizeInt);
var
  Mate, tmp: SizeInt;
begin
  repeat
    Mate := FParents[aRoot];
    tmp := FMates[Mate];
    Match(aRoot, Mate);
    aRoot := tmp;
  until aRoot = NULL_INDEX;
end;

procedure TGSimpleGraph.TEdMatchHelper.EdMatch;
var
  I, Last: SizeInt;
begin
  for I := 0 to System.High(FMates) do
    if (FMates[I] = NULL_INDEX) and FindAugmentPath(I, Last) then
      begin
        AlternatePath(Last);
        Inc(FMatchCount);
      end;
end;

procedure TGSimpleGraph.TEdMatchHelper.Init(aGraph: TGSimpleGraph);
var
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FMates := aGraph.CreateIntArray;
  FBase := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FVisited.Capacity := aGraph.VertexCount;
  FLcaUsed.Capacity := aGraph.VertexCount;
  FBlossoms.Capacity := aGraph.VertexCount;
  for e in aGraph.GreedyMatching2 do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TEdMatchHelper.Execute(aGraph: TGSimpleGraph): TIntEdgeArray;
var
  I, J: SizeInt;
begin
  Init(aGraph);
  EdMatch;
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I := 0 to System.High(FMates) do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        FMates[FMates[I]] := NULL_INDEX;
        Inc(J);
      end;
end;

{ TGSimpleGraph.TPcMatchHelper }

procedure TGSimpleGraph.TPcMatchHelper.Match(aNode, aMate: SizeInt);
begin
  FMates[aNode] := aMate;
  FMates[aMate] := aNode;
end;

procedure TGSimpleGraph.TPcMatchHelper.FindAugmentPath(aSource: SizeInt);
var
  Curr, Next, Mate, Tmp: SizeInt;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FInTree.ClearBits;
  FInTree.UncBits[aSource] := True;
  FQueue[qTail] := aSource;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      for p in FGraph.AdjLists[Curr]^ do
        if not FInTree.UncBits[p^.Destination] then
          begin
            Next := p^.Destination;
            Mate := FMates[Next];
            if Mate = NULL_INDEX then
              begin
                FMates[Next] := Curr;
                repeat
                  Tmp := FMates[Curr];
                  FMates[Curr] := Next;
                  if Tmp <> NULL_INDEX then
                    begin
                      Curr := FGrannies[Curr];
                      FMates[Tmp] := Curr;
                      Next := Tmp;
                    end;
                until Tmp = NULL_INDEX;
                Inc(FMatchCount);
                exit;
              end
            else
              if Mate <> Curr then
                begin
                  if Curr <> aSource then
                    begin
                      Tmp := Curr;
                      repeat Tmp := FGrannies[Tmp];
                      until (Tmp = aSource) or (Tmp = Next);
                      if Tmp <> aSource then
                        continue;
                    end;
                  FInTree.UncBits[Next] := True;
                  FGrannies[Mate] := Curr;
                  FQueue[qTail] := Mate;
                  Inc(qTail);
                end;
          end;
    end;
end;

procedure TGSimpleGraph.TPcMatchHelper.Init(aGraph: TGSimpleGraph);
var
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FMates := aGraph.CreateIntArray;
  FGrannies := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FInTree.Capacity := aGraph.VertexCount;
  for e in aGraph.GreedyMatching do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TPcMatchHelper.Execute(aGraph: TGSimpleGraph): TIntEdgeArray;
var
  I, J: SizeInt;
begin
  Init(aGraph);
  for I := 0 to System.High(FMates) do
    if FMates[I] = NULL_INDEX then
      FindAugmentPath(I);
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I := 0 to System.High(FMates) do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        FMates[FMates[I]] := NULL_INDEX;
        Inc(J);
      end;
end;

{ TGSimpleGraph.TNISimpMinCutHelper.TNiEdge }

constructor TGSimpleGraph.TNISimpMinCutHelper.TNiEdge.Create(aTarget, aWeight: SizeInt);
begin
  Target := aTarget;
  Weight := aWeight;
end;

{ TGSimpleGraph.TNISimpMinCutHelper }

procedure TGSimpleGraph.TNISimpMinCutHelper.ClearMarks;
var
  I: SizeInt;
  p: TNiAdjList.PEntry;
begin
  for I in FExistNodes do
    for p in FGraph[I] do
      p^.Scanned := False;
end;

procedure TGSimpleGraph.TNISimpMinCutHelper.Init(aGraph: TGSimpleGraph; aCutsNeeded: Boolean);
var
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FGraph, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FGraph[I].EnsureCapacity(aGraph.DegreeI(I));
      for p in aGraph.AdjLists[I]^ do
        FGraph[I].Add(TNiEdge.Create(p^.Destination, 1));
    end;
  if aCutsNeeded then
    begin
      System.SetLength(FCuts, aGraph.VertexCount);
      for I := 0 to Pred(aGraph.VertexCount) do
        FCuts[I].Add(I);
    end
  else
    FCuts := nil;
  FQueue := TQueue.Create(aGraph.VertexCount);
  FExistNodes.InitRange(aGraph.VertexCount);
  FInQueue.Capacity := aGraph.VertexCount;
  FBestCut := High(SizeInt);
end;

procedure TGSimpleGraph.TNISimpMinCutHelper.ShrinkEdge(aSource, aTarget: SizeInt);
var
  I: SizeInt;
  p: TNiAdjList.PEntry;
  Edge: TNiEdge;
begin
  FGraph[aSource].Remove(aTarget);
  FGraph[aTarget].Remove(aSource);
  FGraph[aSource].AddAll(FGraph[aTarget]);
  for p in FGraph[aTarget] do
    begin
      I := p^.Target;
      Edge := p^;
      FGraph[I].Remove(aTarget);
      Edge.Target := aSource;
      FGraph[I].Add(Edge);
    end;
  Finalize(FGraph[aTarget]);
  FExistNodes.UncBits[aTarget] := False;
  if FCuts <> nil then
    begin
      while FCuts[aTarget].TryPop(I) do
        FCuts[aSource].Push(I);
      Finalize(FCuts[aTarget]);
    end;
end;

procedure TGSimpleGraph.TNISimpMinCutHelper.ScanFirstSearch;
var
  I: SizeInt;
  p: TNiAdjList.PEntry;
  Item: TIntNode;
begin
  ClearMarks;
  FInQueue.Join(FExistNodes);
  for I in FExistNodes do
    FQueue.Enqueue(I, TIntNode.Create(I, 0));
  while FQueue.Count > 1 do
    begin
      I := FQueue.Dequeue.Index;
      FInQueue.UncBits[I] := False;
      for p in FGraph[I] do
        if FInQueue.UncBits[p^.Target] then
          begin
            Item := FQueue.GetItem(p^.Target);
            Item.Data += p^.Weight;
            FQueue.Update(p^.Target, Item);
            p^.Scanned := True;
            p^.ScanRank := Item.Data;
          end;
    end;
  Item := FQueue.Dequeue;
  FInQueue.UncBits[Item.Index] := False;
  if Item.Data < FBestCut then
    begin
      FBestCut := Item.Data;
      if FCuts <> nil then
        FBestSet.Assign(FCuts[Item.Index]);
    end;
end;

procedure TGSimpleGraph.TNISimpMinCutHelper.Shrink;
var
  I: SizeInt;
  p: TNiAdjList.PEntry;
  Pair: TOrdIntPair;
begin
  ScanFirstSearch;
  for I in FExistNodes do
    for p in FGraph[I] do
      if p^.Scanned and (p^.ScanRank >= FBestCut) then
        FEdgeQueue.Enqueue(TOrdIntPair.Create(I, p^.Target));
  while FEdgeQueue.TryDequeue(Pair) do
    if FExistNodes.UncBits[Pair.Left] and FExistNodes.UncBits[Pair.Right] then
      ShrinkEdge(Pair.Left, Pair.Right);
end;

function TGSimpleGraph.TNISimpMinCutHelper.Execute(aGraph: TGSimpleGraph): SizeInt;
begin
  Init(aGraph, False);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
end;

function TGSimpleGraph.TNISimpMinCutHelper.Execute(aGraph: TGSimpleGraph; out aCut: TIntSet): SizeInt;
begin
  Init(aGraph, True);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
  aCut.Assign(FBestSet);
end;

{ TGSimpleGraph.TPlanarHelper.TArc }

constructor TGSimpleGraph.TPlanarHelper.TArc.Create(aSource, aTarget: PNode);
begin
  Source := aSource;
  Target := aTarget;
  LowPt := NULL_INDEX;
  NestingDepth := NULL_INDEX;
  LowPtArc := nil;
  Ref := nil;
  Side := RIGHT_SIDE;
end;

function TGSimpleGraph.TPlanarHelper.TArc.Sign: ShortInt;
begin
  if Ref <> nil then
    begin
      Side *= Ref^.Sign;
      Ref := nil;
    end;
  Result := Side;
end;

{ TGSimpleGraph.TPlanarHelper.TArcCmp }

class function TGSimpleGraph.TPlanarHelper.TArcCmp.Less(L, R: PArc): Boolean;
begin
  Result := L^.NestingDepth < R^.NestingDepth;
end;

{ TGSimpleGraph.TPlanarHelper.TNode }

constructor TGSimpleGraph.TPlanarHelper.TNode.Create(aFirstArc: SizeInt);
begin
  FirstArc := aFirstArc;
  Height := NULL_INDEX;
  ParentArc := nil;
end;

{ TGSimpleGraph.TPlanarHelper.TInterval }

constructor TGSimpleGraph.TPlanarHelper.TInterval.Create(aLowArc, aHighArc: PArc);
begin
  LowA := aLowArc;
  HighA := aHighArc;
end;

function TGSimpleGraph.TPlanarHelper.TInterval.IsEmpty: Boolean;
begin
  Result := (LowA = nil) or (HighA = nil);
end;

function TGSimpleGraph.TPlanarHelper.TInterval.Conflicting(aArc: PArc): Boolean;
begin
  if IsEmpty then
    exit(False);
  Result := HighA^.LowPt > aArc^.LowPt;
end;

{ TGSimpleGraph.TPlanarHelper.TConflictPair }

constructor TGSimpleGraph.TPlanarHelper.TConflictPair.Create(const aRight: TInterval);
begin
  Left := Default(TInterval);
  Right := aRight;
end;

procedure TGSimpleGraph.TPlanarHelper.TConflictPair.Swap;
var
  Tmp: TInterval;
begin
  Tmp := Left;
  Left := Right;
  Right := Tmp;
end;

function TGSimpleGraph.TPlanarHelper.TConflictPair.Lowest: SizeInt;
begin
  if Left.IsEmpty then
    exit(Right.LowA^.LowPt);
  if Right.IsEmpty then
    exit(Left.LowA^.LowPt);
  Result := TPlanarHelper.Min(Left.LowA^.LowPt, Right.LowA^.LowPt);
end;

{ TGSimpleGraph.TPlanarHelper }

function TGSimpleGraph.TPlanarHelper.IdxOfNode(aNode: PNode): SizeInt;
begin
  Result := aNode - PNode(FNodes);
end;

function TGSimpleGraph.TPlanarHelper.IdxOfArc(aArc: PArc): SizeInt;
begin
  Result := aArc - PArc(FArcs);
end;

procedure TGSimpleGraph.TPlanarHelper.CreateDigraphR;
var
  Arcs: array of record Target, Reverse: SizeInt; Passed, Used: Boolean end;
  NodeArcs: TIntArray = nil;
  Visited: TBoolVector;

  procedure Dfs(aRootIdx: SizeInt);
  var
    I: SizeInt;
  begin
    for I := NodeArcs[aRootIdx] to NodeArcs[aRootIdx+1]-1 do
      if not Arcs[I].Passed then
        begin
          Arcs[I].Passed := True;
          Arcs[I].Used := True;
          Arcs[Arcs[I].Reverse].Passed := True;
          if not Visited.UncBits[Arcs[I].Target] then
            begin
              Visited.UncBits[Arcs[I].Target] := True;
              Dfs(Arcs[I].Target);
            end;
        end;
  end;

var
  I, J, Curr, CurrRev: SizeInt;
  p: PAdjItem;
begin
  NodeArcs.Length := Succ(FGraph.VertexCount);
  Curr := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      NodeArcs[I] := Curr;
      Curr += FGraph.AdjLists[I]^.Count;
    end;
  System.SetLength(Arcs, FGraph.EdgeCount * 2);
  for I := 0 to Pred(FGraph.VertexCount) do
    for p in FGraph.AdjLists[I]^ do
      if p^.Key > I then
        begin
          Curr := NodeArcs[I];
          CurrRev := NodeArcs[p^.Key];
          Arcs[Curr].Target := p^.Key;
          Arcs[Curr].Reverse := CurrRev;
          Arcs[Curr].Passed := False;
          Arcs[Curr].Used := False;
          Arcs[CurrRev].Target := I;
          Arcs[CurrRev].Reverse := Curr;
          Arcs[CurrRev].Passed := False;
          Arcs[CurrRev].Used := False;
          Inc(NodeArcs[I]);
          Inc(NodeArcs[p^.Key]);
        end;

  Curr := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      NodeArcs[I] := Curr;
      Curr += FGraph.AdjLists[I]^.Count;
    end;
  NodeArcs[FGraph.VertexCount] := Curr;
  Visited.Capacity := FGraph.VertexCount;
  for I := 0 to Pred(FGraph.VertexCount) do
    if not Visited.UncBits[I] then
      begin
        FRoots.Add(I);
        Visited.UncBits[I] := True;
        Dfs(I);
      end;

  System.SetLength(FNodes, Succ(FGraph.VertexCount));
  System.SetLength(FArcs, FGraph.EdgeCount);
  System.SetLength(FSortedArcs, FGraph.EdgeCount);
  J := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      FNodes[I] := TNode.Create(J);
      for Curr := NodeArcs[I] to NodeArcs[I+1]-1 do
        if Arcs[Curr].Used then
          begin
            FArcs[J] := TArc.Create(@FNodes[I], @FNodes[Arcs[Curr].Target]);
            FSortedArcs[J] := @FArcs[J];
            Inc(J);
          end;
    end;
  FNodes[FGraph.VertexCount] := TNode.Create(J);
end;

procedure TGSimpleGraph.TPlanarHelper.CreateDigraph;
var
  Arcs: array of record Target, Reverse: SizeInt; Passed, Used: Boolean end;
  NodeArcs: array of record FirstArc, CurrArc: SizeInt end;
  Visited: TBoolVector;

  procedure Dfs(aRootIdx: SizeInt);
  var
    Stack: TIntArray = nil;
    I, CurrNode: SizeInt;
    sTop: SizeInt = 0;
  begin
    Stack.Length := FGraph.VertexCount;
    Stack[0] := aRootIdx;
    while sTop >= 0 do
      begin
        CurrNode := Stack[sTop];
        if NodeArcs[CurrNode].CurrArc < NodeArcs[CurrNode+1].FirstArc then
          begin
            I := NodeArcs[CurrNode].CurrArc;
            if not Arcs[I].Passed then
              begin
                Arcs[I].Passed := True;
                Arcs[I].Used := True;
                Arcs[Arcs[I].Reverse].Passed := True;
                if not Visited.UncBits[Arcs[I].Target] then
                  begin
                    Visited.UncBits[Arcs[I].Target] := True;
                    Inc(sTop);
                    Stack[sTop] := Arcs[I].Target;
                  end;
              end;
            Inc(NodeArcs[CurrNode].CurrArc);
          end
        else
          Dec(sTop);
      end;
  end;

var
  I, J, Curr, CurrRev: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(NodeArcs, Succ(FGraph.VertexCount));
  Curr := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      NodeArcs[I].FirstArc := Curr;
      Curr += FGraph.AdjLists[I]^.Count;
    end;
  System.SetLength(Arcs, FGraph.EdgeCount * 2);
  for I := 0 to Pred(FGraph.VertexCount) do
    for p in FGraph.AdjLists[I]^ do
      if p^.Key > I then
        begin
          Curr := NodeArcs[I].FirstArc;
          CurrRev := NodeArcs[p^.Key].FirstArc;
          Arcs[Curr].Target := p^.Key;
          Arcs[Curr].Reverse := CurrRev;
          Arcs[Curr].Passed := False;
          Arcs[Curr].Used := False;
          Arcs[CurrRev].Target := I;
          Arcs[CurrRev].Reverse := Curr;
          Arcs[CurrRev].Passed := False;
          Arcs[CurrRev].Used := False;
          Inc(NodeArcs[I].FirstArc);
          Inc(NodeArcs[p^.Key].FirstArc);
        end;

  Curr := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      NodeArcs[I].FirstArc := Curr;
      NodeArcs[I].CurrArc := Curr;
      Curr += FGraph.AdjLists[I]^.Count;
    end;
  NodeArcs[FGraph.VertexCount].FirstArc := Curr;
  Visited.Capacity := FGraph.VertexCount;
  for I := 0 to Pred(FGraph.VertexCount) do
    if not Visited.UncBits[I] then
      begin
        FRoots.Add(I);
        Visited.UncBits[I] := True;
        Dfs(I);
      end;

  System.SetLength(FNodes, Succ(FGraph.VertexCount));
  System.SetLength(FArcs, FGraph.EdgeCount);
  System.SetLength(FSortedArcs, FGraph.EdgeCount);
  J := 0;
  for I := 0 to Pred(FGraph.VertexCount) do
    begin
      FNodes[I] := TNode.Create(J);
      for Curr := NodeArcs[I].FirstArc to NodeArcs[I+1].FirstArc-1 do
        if Arcs[Curr].Used then
          begin
            FArcs[J] := TArc.Create(@FNodes[I], @FNodes[Arcs[Curr].Target]);
            FSortedArcs[J] := @FArcs[J];
            Inc(J);
          end;
    end;
  FNodes[FGraph.VertexCount] := TNode.Create(J);
end;

procedure TGSimpleGraph.TPlanarHelper.Dfs1R(aRootIdx: SizeInt);
var
  Arc, ParentArc: PArc;
  Next: PNode;
  I, RootHeight: SizeInt;
begin
  ParentArc := FNodes[aRootIdx].ParentArc;
  RootHeight := FNodes[aRootIdx].Height;
  for I := FNodes[aRootIdx].FirstArc to FNodes[aRootIdx+1].FirstArc-1 do
    begin
      Arc := FSortedArcs[I];
      Arc^.LowPt := RootHeight;
      FLowPt2[IdxOfArc(Arc)] := RootHeight;
      Next := Arc^.Target;
      if Next^.Height = NULL_INDEX then //tree arc
        begin
          Next^.ParentArc := Arc;
          Next^.Height := Succ(RootHeight);
          Dfs1R(IdxOfNode(Next));
        end
      else
        Arc^.LowPt := Next^.Height;

      Arc^.NestingDepth := Arc^.LowPt shl 1;
      if FLowPt2[IdxOfArc(Arc)] < RootHeight then // chordal
        Inc(Arc^.NestingDepth);

      if ParentArc <> nil then // node is not dfs tree root
        if Arc^.LowPt < ParentArc^.LowPt then
          begin
            FLowPt2[IdxOfArc(ParentArc)] := Min(ParentArc^.LowPt, FLowPt2[IdxOfArc(Arc)]);
            ParentArc^.LowPt := Arc^.LowPt;
          end
        else
          if Arc^.LowPt > ParentArc^.LowPt then
            FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)], Arc^.LowPt)
          else
            FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)], FLowPt2[IdxOfArc(Arc)]);
    end;
end;

procedure TGSimpleGraph.TPlanarHelper.CreateOrientationR;
var
  I: SizeInt;
begin
  CreateDigraphR;
  FLowPt2.Length := FGraph.EdgeCount;
  for I in FRoots do
    begin
      FNodes[I].Height := 0;
      Dfs1R(I);
    end;
  FLowPt2 := nil;
end;

procedure TGSimpleGraph.TPlanarHelper.CreateOrientation;
  procedure Dfs(aRootIdx: SizeInt);
  var
    Stack: TIntArray = nil;
    CurrArc: TIntArray = nil;
    Arc, ParentArc: PArc;
    Next: PNode;
    I, CurrNode, ParentHeight: SizeInt;
    sTop: SizeInt = 0;
  begin
    Stack.Length := Pred(System.Length(FNodes));
    CurrArc.Length := Pred(System.Length(FNodes));
    for I := 0 to System.High(CurrArc) do
      CurrArc[I] := FNodes[I].FirstArc;
    Stack[0] := aRootIdx;
    while sTop >= 0 do
      begin
        CurrNode := Stack[sTop];
        if CurrArc[CurrNode] < FNodes[CurrNode+1].FirstArc then
          begin
            Arc := FSortedArcs[CurrArc[CurrNode]];
            ParentArc := FNodes[CurrNode].ParentArc;
            ParentHeight := FNodes[CurrNode].Height;
            Arc^.LowPt := ParentHeight;
            FLowPt2[IdxOfArc(Arc)] := ParentHeight;
            Next := Arc^.Target;
            if Next^.Height = NULL_INDEX then //tree arc
              begin
                Next^.ParentArc := Arc;
                Next^.Height := Succ(ParentHeight);
                Inc(sTop);
                Stack[sTop] := IdxOfNode(Next);
              end
            else
              begin
                Arc^.LowPt := Next^.Height;

                Arc^.NestingDepth := Arc^.LowPt shl 1;
                if FLowPt2[IdxOfArc(Arc)] < ParentHeight then // chordal
                  Inc(Arc^.NestingDepth);

                if ParentArc <> nil then // node is not dfs tree root
                  if Arc^.LowPt < ParentArc^.LowPt then
                    begin
                      FLowPt2[IdxOfArc(ParentArc)] := Min(ParentArc^.LowPt, FLowPt2[IdxOfArc(Arc)]);
                      ParentArc^.LowPt := Arc^.LowPt;
                    end
                  else
                    if Arc^.LowPt > ParentArc^.LowPt then
                      FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)], Arc^.LowPt)
                    else
                      FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)],
                                                           FLowPt2[IdxOfArc(Arc)]);
              end;
            Inc(CurrArc[CurrNode]);
          end
        else
          begin
            Dec(sTop);
            if FNodes[CurrNode].ParentArc = nil then
              continue;
            Arc := FNodes[CurrNode].ParentArc;
            ParentArc := Arc^.Source^.ParentArc;
            ParentHeight := Arc^.Source^.Height;

            Arc^.NestingDepth := Arc^.LowPt shl 1;
            if FLowPt2[IdxOfArc(Arc)] < ParentHeight then // chordal
              Inc(Arc^.NestingDepth);

            if ParentArc <> nil then
              if Arc^.LowPt < ParentArc^.LowPt then
                begin
                  FLowPt2[IdxOfArc(ParentArc)] := Min(ParentArc^.LowPt, FLowPt2[IdxOfArc(Arc)]);
                  ParentArc^.LowPt := Arc^.LowPt;
                end
              else
                if Arc^.LowPt > ParentArc^.LowPt then
                  FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)], Arc^.LowPt)
                else
                  FLowPt2[IdxOfArc(ParentArc)] := Min(FLowPt2[IdxOfArc(ParentArc)],
                                                       FLowPt2[IdxOfArc(Arc)]);
          end;
      end;
  end;
var
  I: SizeInt;
begin
  CreateDigraph;
  FLowPt2.Length := FGraph.EdgeCount;
  for I in FRoots do
    begin
      FNodes[I].Height := 0;
      Dfs(I);
    end;
  FLowPt2 := nil;
end;

procedure TGSimpleGraph.TPlanarHelper.SortAdjLists;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(FNodes)) do
    TSortHelper.Sort(FSortedArcs[FNodes[I].FirstArc..FNodes[I+1].FirstArc-1]);
end;

procedure TGSimpleGraph.TPlanarHelper.Dfs2R(aRootIdx: SizeInt);
var
  Arc, ParentArc, hL, hR: PArc;
  I: SizeInt;
begin
  ParentArc := FNodes[aRootIdx].ParentArc;
  for I := FNodes[aRootIdx].FirstArc to FNodes[aRootIdx+1].FirstArc-1 do
    begin
      Arc := FSortedArcs[I];
      FStackBottom[IdxOfArc(Arc)] := FPairStack.Count;
      if Arc = Arc^.Target^.ParentArc then  // tree arc
        begin
          Dfs2R(IdxOfNode(Arc^.Target));
          if not FPlanar then
            exit;
        end
      else
        begin
          Arc^.LowPtArc := Arc;
          FPairStack.Push(TConflictPair.Create(TInterval.Create(Arc, Arc)));
        end;
      if Arc^.LowPt < FNodes[aRootIdx].Height then //has return arc
        if I <> FNodes[aRootIdx].FirstArc then
          begin
            AddConstraints(ParentArc, Arc);
            if not FPlanar then
              exit;
          end
        else
          ParentArc^.LowPtArc := Arc^.LowPtArc;
    end;
  if ParentArc <> nil then   // node is not tree root
    begin
      TrimBackArcs(ParentArc^.Source);
      if ParentArc^.LowPt < ParentArc^.Source^.Height then // ParentArc has return arc
        begin
          with FPairStack.PeekItem^ do
            begin
              hL := Left.HighA;
              hR := Right.HighA;
            end;
          if (hL <> nil) and ((hR = nil) or (hL^.LowPt > hR^.LowPt)) then
            ParentArc^.Ref := hL
          else
            ParentArc^.Ref := hR;
        end;
    end;
end;

procedure TGSimpleGraph.TPlanarHelper.AddConstraints(aParentArc, aArc: PArc);
var
  P, Q: TConflictPair;
  pTop: PConflictPair = nil;
begin
  P := Default(TConflictPair);
  // merge return arcs of aArc into P.Right
  repeat
    Q := FPairStack.Pop;
    if not Q.Left.IsEmpty then
      Q.Swap;
    if not Q.Left.IsEmpty then
      begin
        FPlanar := False;
        exit;
      end;
    if Q.Right.LowA^.LowPt > aParentArc^.LowPt then // merge intervals
      begin
        if P.Right.IsEmpty then  // topmost interval
          P.Right.HighA := Q.Right.HighA
        else
          P.Right.LowA^.Ref := Q.Right.HighA;
        P.Right.LowA := Q.Right.LowA;
      end
    else  // align
      Q.Right.LowA^.Ref := aParentArc^.LowPtArc;
  until FPairStack.Count = FStackBottom[IdxOfArc(aArc)];
  // merge conflicting return arcs of prev(aArc) into P.Left
  while FPairStack.TryPeekItem(pTop) do
    begin
      if not(pTop^.Left.Conflicting(aArc) or pTop^.Right.Conflicting(aArc)) then
        break;
      Q := FPairStack.Pop;
      if Q.Right.Conflicting(aArc) then
        Q.Swap;
      if Q.Right.Conflicting(aArc) then
        begin
          FPlanar := False;
          exit;
        end;
      // merge interval below lowpt(aArc) into P.Right
      P.Right.LowA^.Ref := Q.Right.HighA;
      if Q.Right.LowA <> nil then
        P.Right.LowA := Q.Right.LowA;
      if P.Left.IsEmpty then    // topmost interval
        P.Left.HighA := Q.Left.HighA
      else
        P.Left.LowA^.Ref := Q.Left.HighA;
      P.Left.LowA := Q.Left.LowA;
    end;
  if not(P.Left.IsEmpty and P.Right.IsEmpty) then
    FPairStack.Push(P);
end;

procedure TGSimpleGraph.TPlanarHelper.TrimBackArcs(aNode: PNode);
var
  P: TConflictPair;
  pTop: PConflictPair = nil;
begin
  while FPairStack.TryPeekItem(pTop) do
    begin
      if pTop^.Lowest <> aNode^.Height then
        break;
      P := FPairStack.Pop;
      if P.Left.LowA <> nil then
        P.Left.LowA^.Side := LEFT_SIDE;
    end;
  if FPairStack.NonEmpty then //one more conflict pair to consider
    begin
      P := FPairStack.Pop;
      // trim left interval
      while (P.Left.HighA <> nil) and (P.Left.HighA^.Target = aNode) do
        P.Left.HighA := P.Left.HighA^.Ref;
      if (P.Left.HighA = nil) and (P.Left.LowA <> nil) then
        begin
          P.Left.LowA^.Ref := P.Right.LowA;
          P.Left.LowA^.Side := LEFT_SIDE;
          P.Left.LowA := nil;
        end;
      // trim right interval
      while (P.Right.HighA <> nil) and (P.Right.HighA^.Target = aNode) do
        P.Right.HighA := P.Right.HighA^.Ref;
      if (P.Right.HighA = nil) and (P.Right.LowA <> nil) then
        begin
          P.Right.LowA^.Ref := P.Left.LowA;
          P.Right.LowA^.Side := LEFT_SIDE;
          P.Right.LowA := nil;
        end;
      FPairStack.Push(P);
    end;
end;

procedure TGSimpleGraph.TPlanarHelper.TestLrPartitionR;
var
  I: SizeInt;
begin
  SortAdjLists;
  FStackBottom.Length := System.Length(FArcs);
  for I in FRoots do
    begin
      Dfs2R(I);
      if not FPlanar then
        break;
    end;
  FStackBottom := nil;
end;

procedure TGSimpleGraph.TPlanarHelper.TestLrPartition;
  procedure Dfs(aRootIdx: SizeInt);
  var
    Stack: TIntArray = nil;
    CurrArc: TIntArray = nil;
    Arc, ParentArc, hL, hR: PArc;
    I, CurrNode: SizeInt;
    Parent: PNode;
    sTop: SizeInt = 0;
    procedure RemoveBackArcs;
    begin
      TrimBackArcs(ParentArc^.Source);
      if ParentArc^.LowPt < ParentArc^.Source^.Height then // ParentArc has return arc
        begin
          with FPairStack.PeekItem^ do
            begin
              hL := Left.HighA;
              hR := Right.HighA;
            end;
          if (hL <> nil) and ((hR = nil) or (hL^.LowPt > hR^.LowPt)) then
            ParentArc^.Ref := hL
          else
            ParentArc^.Ref := hR;
        end;
    end;
  begin
    Stack.Length := Pred(System.Length(FNodes));
    CurrArc.Length := Pred(System.Length(FNodes));
    for I := 0 to System.High(CurrArc) do
      CurrArc[I] := FNodes[I].FirstArc;
    Stack[0] := aRootIdx;
    while sTop >= 0 do
      begin
        CurrNode := Stack[sTop];
        if CurrArc[CurrNode] < FNodes[CurrNode+1].FirstArc then
          begin
            Arc := FSortedArcs[CurrArc[CurrNode]];
            FStackBottom[IdxOfArc(Arc)] := FPairStack.Count;
            if Arc = Arc^.Target^.ParentArc then  // tree arc
              begin
                Inc(sTop);
                Stack[sTop] := IdxOfNode(Arc^.Target);
              end
            else
              begin
                Arc^.LowPtArc := Arc;
                FPairStack.Push(TConflictPair.Create(TInterval.Create(Arc, Arc)));
                ParentArc := FNodes[CurrNode].ParentArc;
                if Arc^.LowPt < FNodes[CurrNode].Height then //has return arc
                  if CurrArc[CurrNode] <> FNodes[CurrNode].FirstArc then
                    begin
                      AddConstraints(ParentArc, Arc);
                      if not FPlanar then
                        exit;
                    end
                  else
                    ParentArc^.LowPtArc := Arc^.LowPtArc;
                if (ParentArc <> nil) and (CurrArc[CurrNode] = FNodes[CurrNode+1].FirstArc-1) then
                  RemoveBackArcs;
              end;
            Inc(CurrArc[CurrNode]);
          end
        else
          begin
            Dec(sTop);
            if FNodes[CurrNode].ParentArc = nil then
              continue;
            Arc := FNodes[CurrNode].ParentArc;
            Parent := Arc^.Source;
            ParentArc := Parent^.ParentArc;
            if Arc^.LowPt < Parent^.Height then //has return arc
              if Arc <> FSortedArcs[Parent^.FirstArc] then
                begin
                  AddConstraints(ParentArc, Arc);
                  if not FPlanar then
                    exit;
                end
              else
                ParentArc^.LowPtArc := Arc^.LowPtArc;

            if ParentArc <> nil then
              if CurrArc[IdxOfNode(Parent)] = FNodes[IdxOfNode(Parent)+1].FirstArc then
                RemoveBackArcs;
          end;
      end;
  end;
var
  I: SizeInt;
begin
  SortAdjLists;
  FStackBottom.Length := System.Length(FArcs);
  for I in FRoots do
    begin
      Dfs(I);
      if not FPlanar then
        break;
    end;
  FStackBottom := nil;
end;

procedure TGSimpleGraph.TPlanarHelper.CreateEmbeddingR(out aEmbed: TPlanarEmbedding);
var
  LeftRef: TIntArray = nil;
  RightRef: TIntArray = nil;
  CompIndex: SizeInt = 0;

  procedure Dfs(aRootIdx: SizeInt);
  var
    Arc: PArc;
    I, EnterArc, Dst: SizeInt;
  begin
    aEmbed.FComponents[CompIndex].Add(aRootIdx);
    for I := FNodes[aRootIdx].FirstArc to FNodes[aRootIdx+1].FirstArc-1 do
      begin
        Arc := FSortedArcs[I];
        Dst := IdxOfNode(Arc^.Target);
        EnterArc := aEmbed.GetReverse(Arc^.LowPt);
        if Arc = FNodes[Dst].ParentArc then  // tree arc
          begin
            aEmbed.InsertFirst(EnterArc);
            LeftRef[aRootIdx] := Arc^.LowPt;
            RightRef[aRootIdx] := Arc^.LowPt;
            Dfs(Dst);
          end
        else
          if Arc^.Side = RIGHT_SIDE then
            aEmbed.InsertAfter(EnterArc, RightRef[Dst])
          else
            begin
              aEmbed.InsertBefore(EnterArc, LeftRef[Dst]);
              LeftRef[Dst] := EnterArc;
            end;
      end;
  end;

var
  I, J: SizeInt;
begin
  for I := 0 to System.High(FArcs) do
    FArcs[I].NestingDepth *= FArcs[I].Sign;
  SortAdjLists;

  aEmbed.Init(FGraph.VertexCount, FGraph.EdgeCount, FRoots.Count);
  for I := 0 to Pred(aEmbed.NodeCount) do
    for J := FNodes[I].FirstArc to FNodes[I+1].FirstArc-1 do
      FSortedArcs[J]^.LowPt := aEmbed.AddEdge(I, IdxOfNode(FSortedArcs[J]^.Target));

  LeftRef.Length := aEmbed.NodeCount;
  RightRef.Length := aEmbed.NodeCount;
  for I in FRoots do
    begin
      Dfs(I);
      Inc(CompIndex);
    end;
end;

procedure TGSimpleGraph.TPlanarHelper.CreateEmbedding(out aEmbed: TPlanarEmbedding);
var
  LeftRef: TIntArray = nil;
  RightRef: TIntArray = nil;
  CompIndex: SizeInt = 0;

  procedure Dfs(aRootIdx: SizeInt);
  var
    Stack: TIntArray = nil;
    CurrArc: TIntArray = nil;
    Arc: PArc;
    I, CurrNode, EnterArc, Dst: SizeInt;
    sTop: SizeInt = 0;
  begin
    Stack.Length := Pred(System.Length(FNodes));
    CurrArc.Length := Pred(System.Length(FNodes));
    for I := 0 to System.High(CurrArc) do
      CurrArc[I] := FNodes[I].FirstArc;
    Stack[0] := aRootIdx;
    while sTop >= 0 do
      begin
        CurrNode := Stack[sTop];
        if CurrArc[CurrNode] < FNodes[CurrNode+1].FirstArc then
          begin
            Arc := FSortedArcs[CurrArc[CurrNode]];
            Dst := IdxOfNode(Arc^.Target);
            EnterArc := aEmbed.GetReverse(Arc^.LowPt);
            if Arc = FNodes[Dst].ParentArc then  // tree arc
              begin
                aEmbed.InsertFirst(EnterArc);
                LeftRef[CurrNode] := Arc^.LowPt;
                RightRef[CurrNode] := Arc^.LowPt;
                aEmbed.FComponents[CompIndex].Add(Dst);
                Inc(sTop);
                Stack[sTop] := Dst;
              end
            else
              if Arc^.Side = RIGHT_SIDE then
                aEmbed.InsertAfter(EnterArc, RightRef[Dst])
              else
                begin
                  aEmbed.InsertBefore(EnterArc, LeftRef[Dst]);
                  LeftRef[Dst] := EnterArc;
                end;
            Inc(CurrArc[CurrNode]);
          end
        else
          Dec(sTop);
      end;
  end;

var
  I, J: SizeInt;
begin
  for I := 0 to System.High(FArcs) do
    FArcs[I].NestingDepth *= FArcs[I].Sign;
  SortAdjLists;

  aEmbed.Init(FGraph.VertexCount, FGraph.EdgeCount, FRoots.Count);
  for I := 0 to Pred(aEmbed.NodeCount) do
    for J := FNodes[I].FirstArc to FNodes[I+1].FirstArc-1 do
      FSortedArcs[J]^.LowPt := aEmbed.AddEdge(I, IdxOfNode(FSortedArcs[J]^.Target));

  LeftRef.Length := aEmbed.NodeCount;
  RightRef.Length := aEmbed.NodeCount;
  for I in FRoots do
    begin
      aEmbed.FComponents[CompIndex].Add(I);
      Dfs(I);
      Inc(CompIndex);
    end;
end;

class function TGSimpleGraph.TPlanarHelper.Min(L, R: SizeInt): SizeInt;
begin
  if R < L then
    Result := R
  else
    Result := L;
end;

function TGSimpleGraph.TPlanarHelper.GraphIsPlanarR(aGraph: TGSimpleGraph): Boolean;
begin
  FPlanar := True;
  FGraph := aGraph;
  CreateOrientationR;
  TestLrPartitionR;
  Result := FPlanar;
end;

function TGSimpleGraph.TPlanarHelper.GraphIsPlanarR(aGraph: TGSimpleGraph;
  out aEmbed: TPlanarEmbedding): Boolean;
begin
  if not GraphIsPlanarR(aGraph) then
    exit(False);
  CreateEmbeddingR(aEmbed);
  Result := True;
end;

function TGSimpleGraph.TPlanarHelper.GraphIsPlanar(aGraph: TGSimpleGraph): Boolean;
begin
  FPlanar := True;
  FGraph := aGraph;
  CreateOrientation;
  TestLrPartition;
  Result := FPlanar;
end;

function TGSimpleGraph.TPlanarHelper.GraphIsPlanar(aGraph: TGSimpleGraph;
  out aEmbed: TPlanarEmbedding): Boolean;
begin
  if not GraphIsPlanar(aGraph) then
    exit(False);
  CreateEmbedding(aEmbed);
  Result := True;
end;

{ TGSimpleGraph.TSbWNode }

class operator TGSimpleGraph.TSbWNode.<(constref L, R: TSbWNode): Boolean;
begin
  if L.WDegree = R.WDegree then
    if L.Degree = R.Degree then
      Result := L.Index < R.Index
    else
      Result := L.Degree < R.Degree
  else
    Result := L.WDegree < R.WDegree;
end;

constructor TGSimpleGraph.TSbWNode.Create(aIndex, aWDegree, aDegree: SizeInt);
begin
  Index := aIndex;
  WDegree := aWDegree;
  Degree := aDegree;
end;
