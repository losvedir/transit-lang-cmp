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

constructor TGAutoEnumerable.TEnumerable.Create(e: TGAutoEnumerable);
begin
  FOwner := e;
end;

function TGAutoEnumerable.TEnumerable.GetEnumerator: TSpecEnumerator;
begin
  FOwner.Reset;
  Result := FOwner;
end;

{ TGAutoEnumerable }

constructor TGAutoEnumerable.Create;
begin
  FEnumerable := TEnumerable.Create(Self);
end;

destructor TGAutoEnumerable.Destroy;
begin
  FEnumerable.Free;
  inherited;
end;

{ TGEnumCursor }

function TGEnumCursor.GetCurrent: T;
begin
  Result := FEnum.GetCurrent;
end;

constructor TGEnumCursor.Create(e: TSpecEnumerator);
begin
  inherited Create;
  FEnum := e;
end;

destructor TGEnumCursor.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGEnumCursor.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGEnumCursor.Reset;
begin
  FEnum.Reset;
end;

{ TGEnumRegularFilter }

function TGEnumRegularFilter.MoveNext: Boolean;
begin
  repeat
    if not FEnum.MoveNext then
      exit(False);
    Result := FTest(FEnum.GetCurrent);
  until Result;
end;

constructor TGEnumRegularFilter.Create(e: TSpecEnumerator; aTest: TTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

{ TGEnumDelegatedFilter }

constructor TGEnumDelegatedFilter.Create(e: TSpecEnumerator; aTest: TOnTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGEnumDelegatedFilter.MoveNext: Boolean;
begin
  repeat
    if not FEnum.MoveNext then
      exit(False);
    Result := FTest(FEnum.GetCurrent);
  until Result;
end;

{ TGEnumNestedFilter }

constructor TGEnumNestedFilter.Create(e: TSpecEnumerator; aTest: TNestTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGEnumNestedFilter.MoveNext: Boolean;
begin
  repeat
    if not FEnum.MoveNext then
      exit(False);
    Result := FTest(FEnum.GetCurrent);
  until Result;
end;

{ TGEnumRegularMap }

constructor TGEnumRegularMap.Create(e: TSpecEnumerator; aMap: TMapFunc);
begin
  inherited Create(e);
  FMap := aMap;
end;

function TGEnumRegularMap.GetCurrent: T;
begin
  Result := FMap(FEnum.GetCurrent);
end;

{ TGEnumDelegatedMap }

constructor TGEnumDelegatedMap.Create(e: TSpecEnumerator; aMap: TOnMap);
begin
  inherited Create(e);
  FMap := aMap;
end;

function TGEnumDelegatedMap.GetCurrent: T;
begin
  Result := FMap(FEnum.GetCurrent);
end;

{ TGEnumNestedMap }

constructor TGEnumNestedMap.Create(e: TSpecEnumerator; aMap: TNestMap);
begin
  inherited Create(e);
  FMap := aMap;
end;

function TGEnumNestedMap.GetCurrent: T;
begin
  Result := FMap(FEnum.GetCurrent);
end;

{ TGSkipEnumerable }

procedure TGSkipEnumerable.Skip;
begin
  while (FSkipped < FSkipCount) and FEnum.MoveNext do
    Inc(FSkipped);
end;

constructor TGSkipEnumerable.Create(e: TSpecEnumerator; aCount: SizeInt);
begin
  inherited Create(e);
  FSkipCount := aCount;
  Skip;
end;

procedure TGSkipEnumerable.Reset;
begin
  inherited;
  FSkipped := 0;
  Skip;
end;

{ TGRegularSkipWhileEnumerable }

constructor TGRegularSkipWhileEnumerable.Create(e: TSpecEnumerator; aTest: TTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGRegularSkipWhileEnumerable.MoveNext: Boolean;
begin
  if not FSkipDone then
    begin
      FSkipDone := True;
      while FEnum.MoveNext do
        if not FTest(FEnum.GetCurrent) then
          exit(True);
      Result := False;
    end
  else
    Result := FEnum.MoveNext;
end;

procedure TGRegularSkipWhileEnumerable.Reset;
begin
  inherited;
  FSkipDone := False;
end;

{ TGDelegatedSkipWhileEnumerable }

constructor TGDelegatedSkipWhileEnumerable.Create(e: TSpecEnumerator; aTest: TOnTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGDelegatedSkipWhileEnumerable.MoveNext: Boolean;
begin
  if not FSkipDone then
    begin
      FSkipDone := True;
      while FEnum.MoveNext do
        if not FTest(FEnum.GetCurrent) then
          exit(True);
      Result := False;
    end
  else
    Result := FEnum.MoveNext;
end;

procedure TGDelegatedSkipWhileEnumerable.Reset;
begin
  inherited;
  FSkipDone := False;
end;

{ TGNestedSkipWhileEnumerable }

constructor TGNestedSkipWhileEnumerable.Create(e: TSpecEnumerator; aTest: TNestTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGNestedSkipWhileEnumerable.MoveNext: Boolean;
begin
  if not FSkipDone then
    begin
      FSkipDone := True;
      while FEnum.MoveNext do
        if not FTest(FEnum.GetCurrent) then
          exit(True);
      Result := False;
    end
  else
    Result := FEnum.MoveNext;
end;

procedure TGNestedSkipWhileEnumerable.Reset;
begin
  inherited;
  FSkipDone := False;
end;


{ TGLimitEnumerable }

constructor TGLimitEnumerable.Create(e: TSpecEnumerator; aCount: SizeInt);
begin
  inherited Create(e);
  FLimit := aCount;
end;

function TGLimitEnumerable.MoveNext: Boolean;
begin
  Result := (FCurrent < FLimit) and FEnum.MoveNext;
  FCurrent += Ord(Result);
end;

procedure TGLimitEnumerable.Reset;
begin
  inherited;
  FCurrent := 0;
end;

{ TGRegularTakeWhileEnumerable }

constructor TGRegularTakeWhileEnumerable.Create(e: TSpecEnumerator; aTest: TTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGRegularTakeWhileEnumerable.MoveNext: Boolean;
begin
  if FDone then exit(False);
  if FEnum.MoveNext and FTest(FEnum.GetCurrent) then exit(True);
  FDone := True;
  Result := False;
end;

procedure TGRegularTakeWhileEnumerable.Reset;
begin
  inherited;
  FDone := False;
end;

{ TGDelegatedTakeWhileEnumerable }

constructor TGDelegatedTakeWhileEnumerable.Create(e: TSpecEnumerator; aTest: TOnTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGDelegatedTakeWhileEnumerable.MoveNext: Boolean;
begin
  if FDone then exit(False);
  if FEnum.MoveNext and FTest(FEnum.GetCurrent) then exit(True);
  FDone := True;
  Result := False;
end;

procedure TGDelegatedTakeWhileEnumerable.Reset;
begin
  inherited;
  FDone := False;
end;

{ TGNestedTakeWhileEnumerable }

constructor TGNestedTakeWhileEnumerable.Create(e: TSpecEnumerator; aTest: TNestTest);
begin
  inherited Create(e);
  FTest := aTest;
end;

function TGNestedTakeWhileEnumerable.MoveNext: Boolean;
begin
  if FDone then exit(False);
  if FEnum.MoveNext and FTest(FEnum.GetCurrent) then exit(True);
  FDone := True;
  Result := False;
end;

procedure TGNestedTakeWhileEnumerable.Reset;
begin
  inherited;
  FDone := False;
end;

{ TGArrayCursor.TArrayEnumerable }

function TGArrayCursor.TArrayEnumerable.ToArray: TArray;
begin
  Result := System.Copy(TGArrayCursor(FOwner).FArray, 0, System.Length(TGArrayCursor(FOwner).FArray));
  FOwner.Free;
end;

{ TGArrayCursor }

function TGArrayCursor.GetCurrent: T;
begin
  Result := FArray[FCurrIndex];
end;

constructor TGArrayCursor.Create(const a: TArray);
begin
  FEnumerable := TArrayEnumerable.Create(Self);
  FArray := a;
  FCurrIndex := NULL_INDEX;
end;

function TGArrayCursor.MoveNext: Boolean;
begin
  Result := FCurrIndex < System.High(FArray);
  FCurrIndex += Ord(Result);
end;

procedure TGArrayCursor.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGArrayReverse.TArrayEnumerable }

function TGArrayReverse.TArrayEnumerable.ToArray: TArray;
begin
  Result := specialize TGArrayHelpUtil<T>.CreateReverseCopy(TGArrayReverse(FOwner).FArray);
  FOwner.Free;
end;

{ TGArrayReverse }

function TGArrayReverse.GetCurrent: T;
begin
  Result := FArray[FPosition];
end;

constructor TGArrayReverse.Create(const a: TArray);
begin
  FEnumerable := TArrayEnumerable.Create(Self);
  FArray := a;
  FPosition := System.Length(a);
end;

function TGArrayReverse.MoveNext: Boolean;
begin
  Result := FPosition > System.Low(FArray);
  FPosition -= Ord(Result);
end;

procedure TGArrayReverse.Reset;
begin
  FPosition := System.Length(FArray);
end;

{ TGArrayEnumerator }

function TGArrayEnumerator.GetCurrent: T;
begin
  Result := FArray[FPosition];
end;

constructor TGArrayEnumerator.Create(const a: TArray);
begin
  FArray := a;
  FLast := System.High(a);
  FPosition := NULL_INDEX;
end;

function TGArrayEnumerator.MoveNext: Boolean;
begin
  Result := FPosition < FLast;
  FPosition += Ord(Result);
end;

procedure TGArrayEnumerator.Reset;
begin
  FPosition := NULL_INDEX;
end;
