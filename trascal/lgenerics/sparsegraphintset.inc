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

{ TGSparseGraph.TIntSet.TEnumerator }

function TGSparseGraph.TIntSet.TEnumerator.GetCurrent: SizeInt;
begin
  Result := pCurr^;
end;

function TGSparseGraph.TIntSet.TEnumerator.MoveNext: Boolean;
begin
  Result := pCurr < pLast;
  pCurr += Ord(Result);
end;

{ TIntSet }

procedure TGSparseGraph.TIntSet.Expand;
begin
  System.SetLength(FItems, System.Length(FItems) + GRAPH_ADJLIST_GROW);
end;

class operator TGSparseGraph.TIntSet.Initialize(var aSet: TIntSet);
begin
  aSet.FCount := 0;
end;

procedure TGSparseGraph.TIntSet.EnsureCapacity(aValue: SizeInt);
begin
  if aValue > System.Length(FItems) then
    System.SetLength(FItems, aValue);
end;

procedure TGSparseGraph.TIntSet.InitRange(aRange: SizeInt);
var
  I: SizeInt;
begin
  System.SetLength(FItems, aRange);
  if aRange > 0 then
    begin
      for I := 0 to Pred(aRange) do
        FItems[I] := I;
      FCount := aRange;
    end
  else
    FCount := 0;
end;

function TGSparseGraph.TIntSet.GetEnumerator: TEnumerator;
begin
  Result.pCurr := PSizeInt(Pointer(FItems)) - Ord(Count > 0);
  Result.pLast := PSizeInt(Pointer(FItems)) + (Pred(Count) and (-SizeInt(Count > 0)));
end;

function TGSparseGraph.TIntSet.ToArray: TIntArray;
begin
  Result := System.Copy(FItems, 0, Count);
end;

procedure TGSparseGraph.TIntSet.Assign(constref aSet: TIntSet);
begin
  FCount := aSet.Count;
  if Count <> 0 then
    FItems := System.Copy(aSet.FItems, 0, Count);
end;

procedure TGSparseGraph.TIntSet.AssignArray(constref a: TIntArray);
begin
  FItems := System.Copy(a);
  FCount := System.Length(FItems);
end;

procedure TGSparseGraph.TIntSet.AssignList(aList: PAdjList);
var
  p: PAdjItem;
  I: SizeInt = 0;
begin
  FCount := aList^.Count;
  System.SetLength(FItems, Count);
  for p in aList^ do
    begin
      FItems[I] := p^.Destination;
      Inc(I);
    end;
end;

procedure TGSparseGraph.TIntSet.Clear;
begin
  FItems := nil;
  FCount := 0;
end;

function TGSparseGraph.TIntSet.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGSparseGraph.TIntSet.NonEmpty: Boolean;
begin
  Result := Count > 0;
end;

procedure TGSparseGraph.TIntSet.MakeEmpty;
begin
  FCount := 0;
end;

function TGSparseGraph.TIntSet.FindFirst(out aValue: SizeInt): Boolean;
begin
  Result := Count <> 0;
  if Result then
    aValue := FItems[Pred(Count)]
end;

function TGSparseGraph.TIntSet.GetItem(aIndex: SizeInt): SizeInt;
begin
  Result := FItems[aIndex];
end;

function TGSparseGraph.TIntSet.Contains(aValue: SizeInt): Boolean;
begin
  Result := Find(aValue) >= 0;
end;

function TGSparseGraph.TIntSet.ContainsAny(constref aSet: TIntSet): Boolean;
var
  I: SizeInt;
begin
  if NonEmpty then
    for I in aSet do
      if Contains(I) then
        exit(True);
  Result := False;
end;

function TGSparseGraph.TIntSet.ContainsAll(constref aSet: TIntSet): Boolean;
var
  I: SizeInt;
begin
  if Count >= aSet.Count then
    begin
      for I in aSet do
        if not Contains(I) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

function TGSparseGraph.TIntSet.Find(aValue: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to Pred(Count) do
    if FItems[I] = aValue then
      exit(I);
  Result := NULL_INDEX;
end;

function TGSparseGraph.TIntSet.Add(aValue: SizeInt): Boolean;
begin
  Result := Find(aValue) < 0;
  if Result then
    begin
      if Count = System.Length(FItems) then
        Expand;
      FItems[Count] := aValue;
      Inc(FCount);
    end;
end;

function TGSparseGraph.TIntSet.Add(constref a: TIntArray): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I in a do
    Add(I);
  Result := Count - Result;
end;

function TGSparseGraph.TIntSet.Join(constref aSet: TIntSet): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I in aSet do
    Result += Ord(Add(I));
end;

procedure TGSparseGraph.TIntSet.Push(aValue: SizeInt);
begin
  if Count = System.Length(FItems) then
    Expand;
  FItems[Count] := aValue;
  Inc(FCount);
end;

function TGSparseGraph.TIntSet.Pop: SizeInt;
begin
  if Count <> 0 then
    begin
      Dec(FCount);
      Result := FItems[Count];
    end
  else
    begin
      EGraphError.Create(SECantAccessEmpty);
      Result := -1;
    end;
end;

function TGSparseGraph.TIntSet.TryPop(out aValue: SizeInt): Boolean;
begin
  Result := Count <> 0;
  if Result then
    begin
      Dec(FCount);
      aValue := FItems[Count];
    end;
end;

function TGSparseGraph.TIntSet.Last: SizeInt;
begin
  if Count <> 0 then
    Result := FItems[Pred(Count)]
  else
    begin
      EGraphError.Create(SECantAccessEmpty);
      Result := -1;
    end;
end;

procedure TGSparseGraph.TIntSet.Subtract(constref aSet: TIntSet);
var
  I, Pos: SizeInt;
begin
  if aSet.NonEmpty then
    begin
      Pos := 0;
      for I := 0 to Pred(Count) do
        if aSet.Contains(FItems[I]) then
          Dec(FCount)
        else
          begin
            FItems[Pos] := FItems[I];
            Inc(Pos);
          end;
    end;
end;

procedure TGSparseGraph.TIntSet.Subtract(aList: PAdjList);
var
  I, Pos: SizeInt;
begin
  if aList^.NonEmpty then
    begin
      Pos := 0;
      for I := 0 to Pred(Count) do
        if aList^.Contains(FItems[I]) then
          Dec(FCount)
        else
          begin
            FItems[Pos] := FItems[I];
            Inc(Pos);
          end;
    end;
end;

function TGSparseGraph.TIntSet.Difference(constref aSet: TIntSet): TIntSet;
begin
  Result.Assign(Self);
  Result.Subtract(aSet);
end;

procedure TGSparseGraph.TIntSet.Intersect(constref aSet: TIntSet);
var
  I, Pos: SizeInt;
begin
  if aSet.NonEmpty then
    begin
      Pos := 0;
      for I := 0 to Pred(Count) do
        if aSet.Contains(FItems[I]) then
          begin
            FItems[Pos] := FItems[I];
            Inc(Pos);
          end
        else
          Dec(FCount);
    end
  else
    MakeEmpty;
end;

procedure TGSparseGraph.TIntSet.Intersect(aList: PAdjList);
var
  I, Pos: SizeInt;
begin
  if aList^.NonEmpty then
    begin
      Pos := 0;
      for I := 0 to Pred(Count) do
        if aList^.Contains(FItems[I]) then
          begin
            FItems[Pos] := FItems[I];
            Inc(Pos);
          end
        else
          Dec(FCount);
    end
  else
    MakeEmpty;
end;

function TGSparseGraph.TIntSet.Intersection(constref aSet: TIntSet): TIntSet;
begin
  Result.Assign(Self);
  Result.Intersect(aSet);
end;

function TGSparseGraph.TIntSet.IntersectionCount(constref aSet: TIntSet): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I in aSet do
    Result += Ord(Contains(I));
end;

function TGSparseGraph.TIntSet.IntersectionCount(aList: PAdjList): SizeInt;
var
  p: PAdjItem;
begin
  Result := 0;
  for p in aList^ do
    Result += Ord(Contains(p^.Destination));
end;

function TGSparseGraph.TIntSet.Remove(aValue: SizeInt): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(Count) do
    if FItems[I] = aValue then
      begin
        Dec(FCount);
        FItems[I] := FItems[Count];
        exit(True);
      end;
  Result := False;
end;

procedure TGSparseGraph.TIntSet.Delete(aValue: SizeInt);
var
  I: SizeInt;
begin
  for I := 0 to Pred(Count) do
    if FItems[I] = aValue then
      begin
        Dec(FCount);
        if I < Count then
          System.Move(FItems[Succ(I)], FItems[I], (Count - I) * SizeOf(SizeInt));
        exit;
      end;
end;

procedure TGSparseGraph.TIntSet.Reverse;
begin
  if Count <> 0 then
    TIntHelper.Reverse(FItems[0..Pred(Count)]);
end;

{ TGSparseGraph.TSkeleton }

function TGSparseGraph.TSkeleton.GetVertexCount: SizeInt;
begin
  Result := System.Length(FAdjLists);
end;

function TGSparseGraph.TSkeleton.GetAdjList(aIndex: SizeInt): PIntSet;
begin
  Result := @FAdjLists[aIndex];
end;

function TGSparseGraph.TSkeleton.GetDegree(aIndex: SizeInt): SizeInt;
begin
  Result := FAdjLists[aIndex].Count;
end;

constructor TGSparseGraph.TSkeleton.Create(aVertCount: SizeInt; aDirected: Boolean);
begin
  System.SetLength(FAdjLists, aVertCount);
  FEdgeCount := 0;
  FDirected := aDirected;
end;

constructor TGSparseGraph.TSkeleton.Create(constref s: TSkeleton);
var
  I: SizeInt;
begin
  System.SetLength(FAdjLists, s.VertexCount);
  FEdgeCount := s.EdgeCount;
  FDirected := s.Directed;
  for I := 0 to Pred(s.VertexCount) do
    FAdjLists[I].Assign(s.FAdjLists[I]);
end;

function TGSparseGraph.TSkeleton.ContainsEdge(aSrc, aDst: SizeInt): Boolean;
begin
  if (aSrc >= 0) and (aSrc < VertexCount) then
    Result := not (aSrc = aDst) and FAdjLists[aSrc].Contains(aDst)
  else
    Result := False;
end;

function TGSparseGraph.TSkeleton.AddEdge(aSrc, aDst: SizeInt): Boolean;
begin
  if (aSrc < 0) or (aSrc >= VertexCount) or (aDst < 0) or (aDst >= VertexCount) then
    exit(False);
  Result := not (aSrc = aDst) and FAdjLists[aSrc].Add(aDst);
  if Result then
    begin
      if not Directed then
        FAdjLists[aDst].Add(aSrc);
      Inc(FEdgeCount);
    end;
end;

function TGSparseGraph.TSkeleton.RemoveEdge(aSrc, aDst: SizeInt): Boolean;
begin
  Result := not (aSrc = aDst) and FAdjLists[aSrc].Remove(aDst);
  if Result then
    begin
      if not Directed then
        FAdjLists[aDst].Remove(aSrc);
      Dec(FEdgeCount);
    end;
end;

