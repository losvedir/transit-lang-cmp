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

{ TGSparseGraph.TSquareBitMatrix }

function TGSparseGraph.TSquareBitMatrix.GetBit(I, J: SizeInt): Boolean;
begin
  Result := (FBits[(SizeUInt(I) * FSize + SizeUInt(J)) shr INT_SIZE_LOG] and
            (SizeUInt(1) shl ((SizeUInt(I) * FSize + SizeUInt(J)) and INT_SIZE_MASK))) <> 0
end;

function TGSparseGraph.TSquareBitMatrix.GetSize: SizeInt;
begin
  Result := FSize;
end;

procedure TGSparseGraph.TSquareBitMatrix.SetBit(I, J: SizeInt; aValue: Boolean);
begin
  if aValue then
    FBits[(SizeUInt(I) * FSize + SizeUInt(J)) shr INT_SIZE_LOG] :=
    FBits[(SizeUInt(I) * FSize + SizeUInt(J)) shr INT_SIZE_LOG] or
          (SizeUInt(1) shl ((SizeUInt(I) * FSize + SizeUInt(J)) and INT_SIZE_MASK))
  else
    FBits[(SizeUInt(I) * FSize + SizeUInt(J)) shr INT_SIZE_LOG] :=
    FBits[(SizeUInt(I) * FSize + SizeUInt(J)) shr INT_SIZE_LOG] and not
          (SizeUInt(1) shl ((SizeUInt(I) * FSize + SizeUInt(J)) and INT_SIZE_MASK));
end;

class operator TGSparseGraph.TSquareBitMatrix.Initialize(var aMatrix: TSquareBitMatrix);
begin
  aMatrix.FBits := nil;
  aMatrix.FSize := 0;
end;

class function TGSparseGraph.TSquareBitMatrix.MaxSize: SizeInt;
begin
  Result := Trunc(Sqrt(High(SizeUInt)));
end;

constructor TGSparseGraph.TSquareBitMatrix.Create(aSize: SizeInt);
var
  s: SizeInt;
begin
  if aSize > 0 then
    if aSize <= MaxSize then
      begin
        FSize := aSize;
        s := Succ((FSize * FSize) shr INT_SIZE_LOG);
        System.SetLength(FBits, s);
        System.FillChar(Pointer(FBits)^, s * SizeOf(SizeUInt), 0);
      end
    else
      raise EGraphError.CreateFmt(SEBitMatrixSizeExceedFmt, [aSize]);
end;

constructor TGSparseGraph.TSquareBitMatrix.CreateAndSet(aSize: SizeInt);
var
  s: SizeInt;
begin
  if aSize > 0 then
    if aSize <= MaxSize then
      begin
        FSize := aSize;
        s := Succ((FSize * FSize) shr INT_SIZE_LOG);
        System.SetLength(FBits, s);
        System.FillChar(Pointer(FBits)^, s * SizeOf(SizeUInt), $ff);
      end
    else
      raise EGraphError.CreateFmt(SEBitMatrixSizeExceedFmt, [aSize]);
end;

procedure TGSparseGraph.TSquareBitMatrix.ClearBits;
begin
  System.FillChar(FBits[0], System.Length(FBits) * SizeOf(SizeUInt), 0);
end;

procedure TGSparseGraph.TSquareBitMatrix.Clear;
begin
  FBits := nil;
  FSize := 0;
end;

{ TGSparseGraph.TBits256.TEnumerator }

function TGSparseGraph.TBits256.TEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TGSparseGraph.TBits256.TEnumerator.FindFirst: Boolean;
var
  I: SizeInt;
begin
  I := FValue^.Bsf;
  if I >= 0 then
    begin
      FLimbIndex := I shr INT_SIZE_LOG;
      FBitIndex := I and INT_SIZE_MASK;
      FCurrLimb := FValue^.FBits[FLimbIndex] and not (SizeUInt(1) shl FBitIndex);
      Result := True;
    end
  else
    begin
      FLimbIndex := LIMB_COUNT;
      FBitIndex := BIT_PER_LIMB;
      Result := False;
    end;
end;

function TGSparseGraph.TBits256.TEnumerator.MoveNext: Boolean;
begin
  if FInCycle then
    repeat
      {$IF DEFINED(CPU64)}
        FBitIndex := ShortInt(BsfQWord(FCurrLimb));
      {$ELSEIF DEFINED(CPU32)}
        FBitIndex := ShortInt(BsfDWord(FCurrLimb));
      {$ELSE}
        FBitIndex := ShortInt(BsfWord(FCurrLimb));
      {$ENDIF}
      Result := FBitIndex >= 0;
      if Result then
        FCurrLimb := FCurrLimb and not (SizeUInt(1) shl FBitIndex)
      else
        begin
          if FLimbIndex >= Pred(LIMB_COUNT) then
            exit(False);
          Inc(FLimbIndex);
          FCurrLimb := FValue^.FBits[FLimbIndex];
        end;
    until Result
  else
    begin
      Result := FindFirst;
      FInCycle := True;
    end;
end;

{ TGSparseGraph.TBits256.TReverseEnumerator }

function TGSparseGraph.TBits256.TReverseEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TGSparseGraph.TBits256.TReverseEnumerator.FindFirst: Boolean;
var
  I: SizeInt;
begin
  I := FValue^.Bsr;
  if I >= 0 then
    begin
      FLimbIndex := I shr INT_SIZE_LOG;
      FBitIndex := I and INT_SIZE_MASK;
      FCurrLimb := FValue^.FBits[FLimbIndex] and not (SizeUInt(1) shl FBitIndex);
      Result := True;
    end
  else
    begin
      FLimbIndex := -1;
      FBitIndex := BIT_PER_LIMB;
      Result := False;
    end;
end;

function TGSparseGraph.TBits256.TReverseEnumerator.MoveNext: Boolean;
begin
  if FInCycle then
    repeat
      {$IF DEFINED(CPU64)}
        FBitIndex := ShortInt(BsrQWord(FCurrLimb));
      {$ELSEIF DEFINED(CPU32)}
        FBitIndex := ShortInt(BsrDWord(FCurrLimb));
      {$ELSE}
        FBitIndex := ShortInt(BsrWord(FCurrLimb));
      {$ENDIF}
      Result := FBitIndex >= 0;
      if Result then
        FCurrLimb := FCurrLimb and not (SizeUInt(1) shl FBitIndex)
      else
        begin
          if FLimbIndex <= 0 then
            exit(False);
          Dec(FLimbIndex);
          FCurrLimb := FValue^.FBits[FLimbIndex];
        end;
    until Result
  else
    begin
      Result := FindFirst;
      FInCycle := True;
    end;
end;

{ TGSparseGraph.TBits256.TReverse }

function TGSparseGraph.TBits256.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result.FValue := FValue;
  Result.FInCycle := False;
end;

{ TGSparseGraph.TBits256 }

function TGSparseGraph.TBits256.GetBit(aIndex: SizeInt): Boolean;
begin
  Result := (FBits[aIndex shr INT_SIZE_LOG] and (SizeUInt(1) shl (aIndex and INT_SIZE_MASK))) <> 0;
end;

procedure TGSparseGraph.TBits256.SetBit(aIndex: SizeInt; aValue: Boolean);
begin
  if aValue then
    FBits[aIndex shr INT_SIZE_LOG] :=
      FBits[aIndex shr INT_SIZE_LOG] or (SizeUInt(1) shl (aIndex and INT_SIZE_MASK))
  else
    FBits[aIndex shr INT_SIZE_LOG] :=
      FBits[aIndex shr INT_SIZE_LOG] and not (SizeUInt(1) shl (aIndex and INT_SIZE_MASK));
end;

function TGSparseGraph.TBits256.GetEnumerator: TEnumerator;
begin
  Result.FValue := @Self;
  Result.FInCycle := False;
end;

function TGSparseGraph.TBits256.Reverse: TReverse;
begin
  Result.FValue := @Self;
end;

procedure TGSparseGraph.TBits256.InitRange(aRange: SizeInt);
var
  msb: SizeInt;
begin
{$IF DEFINED(CPU64)}
  System.FillQWord(FBits[0], LIMB_COUNT, 0);
{$ELSEIF DEFINED(CPU32)}
  System.FillDWord(FBits[0], LIMB_COUNT, 0);
{$ELSE}
  System.FillWord(FBits[0], LIMB_COUNT, 0);
{$ENDIF}
  if aRange > 0 then
    begin
      msb := aRange and INT_SIZE_MASK;
      aRange := aRange shr INT_SIZE_LOG  + Ord(msb <> 0);
      System.FillChar(FBits[0], aRange * SizeOf(SizeUInt), $ff);
      if msb <> 0 then
        FBits[Pred(aRange)] := FBits[Pred(aRange)] shr (BitsizeOf(SizeUint) - msb);
    end;
end;

procedure TGSparseGraph.TBits256.InitZero;
begin
{$IF DEFINED(CPU64)}
  System.FillQWord(FBits[0], LIMB_COUNT, 0);
{$ELSEIF DEFINED(CPU32)}
  System.FillDWord(FBits[0], LIMB_COUNT, 0);
{$ELSE}
  System.FillWord(FBits[0], LIMB_COUNT, 0);
{$ENDIF}
end;

function TGSparseGraph.TBits256.ToArray: TIntArray;
var
  I, Pos: SizeInt;
begin
  System.SetLength(Result, PopCount);
  Pos := 0;
  for I in Self do
    begin
      Result[Pos] := I;
      Inc(Pos);
    end;
end;

function TGSparseGraph.TBits256.IsEmpty: Boolean;
var
  I: SizeUInt;
begin
  for I in FBits do
    if I <> 0 then
      exit(False);
  Result := True;
end;

function TGSparseGraph.TBits256.NonEmpty: Boolean;
begin
  Result := not IsEmpty;
end;

function TGSparseGraph.TBits256.Bsf: SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] <> 0 then
      exit(
        {$IF DEFINED(CPU64)}
          I shl INT_SIZE_LOG + ShortInt(BsfQWord(FBits[I]))
        {$ELSEIF DEFINED(CPU32)}
          I shl INT_SIZE_LOG + ShortInt(BsfDWord(FBits[I]))
        {$ELSE}
          I shl INT_SIZE_LOG + ShortInt(BsfWord(FBits[I]))
        {$ENDIF});
  Result := -1;
end;

function TGSparseGraph.TBits256.Bsr: SizeInt;
var
  I: SizeInt;
begin
  for I := Pred(LIMB_COUNT) downto 0 do
    if FBits[I] <> 0 then
      exit(
        {$IF DEFINED(CPU64)}
          I shl INT_SIZE_LOG + ShortInt(BsrQWord(FBits[I]))
        {$ELSEIF DEFINED(CPU32)}
          I shl INT_SIZE_LOG + ShortInt(BsrDWord(FBits[I]))
        {$ELSE}
          I shl INT_SIZE_LOG + ShortInt(BsrWord(FBits[I]))
        {$ENDIF});
  Result := -1;
end;

function TGSparseGraph.TBits256.Intersecting(const aValue: TBits256): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] and aValue.FBits[I] <> 0 then
      exit(True);
  Result := False;
end;

function TGSparseGraph.TBits256.IntersectionPop(const aValue: TBits256): SizeInt;
{$IF DEFINED(CPU64)}
begin
  Result := SizeInt(PopCnt(FBits[0] and aValue.FBits[0])) +
            SizeInt(PopCnt(FBits[1] and aValue.FBits[1])) +
            SizeInt(PopCnt(FBits[2] and aValue.FBits[2])) +
            SizeInt(PopCnt(FBits[3] and aValue.FBits[3]));
{$ELSEIF DEFINED(CPU32)}
begin
  Result := SizeInt(PopCnt(FBits[0] and aValue.FBits[0])) +
            SizeInt(PopCnt(FBits[1] and aValue.FBits[1])) +
            SizeInt(PopCnt(FBits[2] and aValue.FBits[2])) +
            SizeInt(PopCnt(FBits[3] and aValue.FBits[3])) +
            SizeInt(PopCnt(FBits[4] and aValue.FBits[4])) +
            SizeInt(PopCnt(FBits[5] and aValue.FBits[5])) +
            SizeInt(PopCnt(FBits[6] and aValue.FBits[6])) +
            SizeInt(PopCnt(FBits[7] and aValue.FBits[7]));
{$ELSE }
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(LIMB_COUNT) do
    Result += SizeInt(PopCnt(FBits[I] and aValue.FBits[I]));
{$ENDIF }
end;

function TGSparseGraph.TBits256.Contains(const aValue: TBits256): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] or aValue.FBits[I] <> FBits[I] then
      exit(False);
  Result := True;
end;

function TGSparseGraph.TBits256.JoinGain(const aValue: TBits256): SizeInt;
{$IF DEFINED(CPU64)}
begin
  Result := SizeInt(PopCnt(not FBits[0] and aValue.FBits[0])) +
            SizeInt(PopCnt(not FBits[1] and aValue.FBits[1])) +
            SizeInt(PopCnt(not FBits[2] and aValue.FBits[2])) +
            SizeInt(PopCnt(not FBits[3] and aValue.FBits[3]));
{$ELSEIF DEFINED(CPU32)}
begin
  Result := SizeInt(PopCnt(not FBits[0] and aValue.FBits[0])) +
            SizeInt(PopCnt(not FBits[1] and aValue.FBits[1])) +
            SizeInt(PopCnt(not FBits[2] and aValue.FBits[2])) +
            SizeInt(PopCnt(not FBits[3] and aValue.FBits[3])) +
            SizeInt(PopCnt(not FBits[4] and aValue.FBits[4])) +
            SizeInt(PopCnt(not FBits[5] and aValue.FBits[5])) +
            SizeInt(PopCnt(not FBits[6] and aValue.FBits[6])) +
            SizeInt(PopCnt(not FBits[7] and aValue.FBits[7]));
{$ELSE }
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(LIMB_COUNT) do
    Result += SizeInt(PopCnt(not FBits[I] and aValue.FBits[I]));
{$ENDIF }
end;

procedure TGSparseGraph.TBits256.Join(const aValue: TBits256);
{$IF DEFINED(CPU64)}
begin
  FBits[0] := FBits[0] or aValue.FBits[0];
  FBits[1] := FBits[1] or aValue.FBits[1];
  FBits[2] := FBits[2] or aValue.FBits[2];
  FBits[3] := FBits[3] or aValue.FBits[3];
{$ELSEIF DEFINED(CPU32)}
begin
  FBits[0] := FBits[0] or aValue.FBits[0];
  FBits[1] := FBits[1] or aValue.FBits[1];
  FBits[2] := FBits[2] or aValue.FBits[2];
  FBits[3] := FBits[3] or aValue.FBits[3];
  FBits[4] := FBits[4] or aValue.FBits[4];
  FBits[5] := FBits[5] or aValue.FBits[5];
  FBits[6] := FBits[6] or aValue.FBits[6];
  FBits[7] := FBits[7] or aValue.FBits[7];
{$ELSE }
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] or aValue.FBits[I];
{$ENDIF }
end;

function TGSparseGraph.TBits256.Union(const aValue: TBits256): TBits256;
begin
  Result := Self;
  Result.Join(aValue);
end;

procedure TGSparseGraph.TBits256.Subtract(const aValue: TBits256);
{$IF DEFINED(CPU64)}
begin
  FBits[0] := FBits[0] and not aValue.FBits[0];
  FBits[1] := FBits[1] and not aValue.FBits[1];
  FBits[2] := FBits[2] and not aValue.FBits[2];
  FBits[3] := FBits[3] and not aValue.FBits[3];
{$ELSEIF DEFINED(CPU32)}
begin
  FBits[0] := FBits[0] and not aValue.FBits[0];
  FBits[1] := FBits[1] and not aValue.FBits[1];
  FBits[2] := FBits[2] and not aValue.FBits[2];
  FBits[3] := FBits[3] and not aValue.FBits[3];
  FBits[4] := FBits[4] and not aValue.FBits[4];
  FBits[5] := FBits[5] and not aValue.FBits[5];
  FBits[6] := FBits[6] and not aValue.FBits[6];
  FBits[7] := FBits[7] and not aValue.FBits[7];
{$ELSE }
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] and not aValue.FBits[I];
{$ENDIF }
end;

function TGSparseGraph.TBits256.Difference(const aValue: TBits256): TBits256;
begin
  Result := Self;
  Result.Subtract(aValue);
end;

procedure TGSparseGraph.TBits256.Intersect(const aValue: TBits256);
{$IF DEFINED(CPU64)}
begin
  FBits[0] := FBits[0] and aValue.FBits[0];
  FBits[1] := FBits[1] and aValue.FBits[1];
  FBits[2] := FBits[2] and aValue.FBits[2];
  FBits[3] := FBits[3] and aValue.FBits[3];
{$ELSEIF DEFINED(CPU32)}
begin
  FBits[0] := FBits[0] and aValue.FBits[0];
  FBits[1] := FBits[1] and aValue.FBits[1];
  FBits[2] := FBits[2] and aValue.FBits[2];
  FBits[3] := FBits[3] and aValue.FBits[3];
  FBits[4] := FBits[4] and aValue.FBits[4];
  FBits[5] := FBits[5] and aValue.FBits[5];
  FBits[6] := FBits[6] and aValue.FBits[6];
  FBits[7] := FBits[7] and aValue.FBits[7];
{$ELSE }
var
  I: SizeInt;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] and aValue.FBits[I];
{$ENDIF }
end;

function TGSparseGraph.TBits256.Intersection(const aValue: TBits256): TBits256;
begin
  Result := Self;
  Result.Intersect(aValue);
end;

function TGSparseGraph.TBits256.PopCount: SizeInt;
{$IF DEFINED(CPU64)}
begin
  Result := SizeInt(PopCnt(FBits[0])) + SizeInt(PopCnt(FBits[1])) +
            SizeInt(PopCnt(FBits[2])) + SizeInt(PopCnt(FBits[3]));
{$ELSEIF DEFINED(CPU32)}
begin
  Result := SizeInt(PopCnt(FBits[0])) + SizeInt(PopCnt(FBits[1])) +
            SizeInt(PopCnt(FBits[2])) + SizeInt(PopCnt(FBits[3])) +
            SizeInt(PopCnt(FBits[4])) + SizeInt(PopCnt(FBits[5])) +
            SizeInt(PopCnt(FBits[6])) + SizeInt(PopCnt(FBits[7]));
{$ELSE }
var
  I: SizeUInt;
begin
  Result := 0;
  for I in FBits do
    Result += SizeInt(PopCnt(I));
{$ENDIF }
end;

