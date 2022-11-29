{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic stack implementations.                                          *
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
unit lgStack;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  lgAbstractContainer;

type

  generic TGStack<T> = class(specialize TGCustomArrayContainer<T>, specialize IGStack<T>)
  strict private
    function  PopItem: T; inline;
  public
    procedure Push(const aValue: T);
    function  PushAll(const a: array of T): SizeInt;
    function  PushAll(e: IEnumerable): SizeInt;
  { EXTRACTS element from the top of stack }
    function  Pop: T;
    function  TryPop(out aValue: T): Boolean;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean;
  end;

  { TGObjectStack note:
    TGObjectStack.Pop(or TGObjectStack.TryPop) EXTRACTS object from stack;
    one need to free this object yourself }
  generic TGObjectStack<T: class> = class(specialize TGStack<T>)
  strict private
    FOwnsObjects: Boolean;
  protected
    procedure DoClear; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(const A: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGThreadStack<T> = class
  public
  type
    IStack = specialize IGStack<T>;

  private
    FStack: IStack;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create(aStack: IStack);
    destructor Destroy; override;
    procedure Clear;
    procedure Push(const aValue: T);
    function  TryPop(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: IStack;
    procedure Unlock; inline;
  end;

  generic TGLiteStack<T> = record
  private
  type
    TBuffer = specialize TGLiteDynBuffer<T>;

  public
  type
    TEnumerator        = TBuffer.TEnumerator;
    TReverseEnumerator = TBuffer.TReverseEnumerator;
    TMutableEnumerator = TBuffer.TMutableEnumerator;
    TMutables          = TBuffer.TMutables;
    TReverse           = TBuffer.TReverse;
    PItem              = TBuffer.PItem;
    TArray             = TBuffer.TArray;

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    function  PopItem: T;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  GetMutableEnumerator: TMutableEnumerator; inline;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Push(const aValue: T); inline;
    function  Pop: T;
    function  TryPop(out aValue: T): Boolean;
    function  Peek: T;
    function  TryPeek(out aValue: T): Boolean;
    function  PeekItem: PItem;
    function  TryPeekItem(out aValue: PItem): Boolean;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGLiteThreadStack<T> = class
  public
  type
    TStack = specialize TGLiteStack<T>;
    PStack = ^TStack;

  strict private
    FStack: TStack;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Push(const aValue: T);
    function  TryPop(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PStack;
    procedure Unlock; inline;
  end;

  generic TGLiteObjectStack<T: class> = record
  strict private
  type
    TStack = specialize TGLiteStack<T>;
    TArray = TStack.TArray;

  var
    FStack: TStack;
    FOwnsObjects: Boolean;
    function  GetCapacity: SizeInt;
    function  GetCount: SizeInt; inline;
    procedure CheckFreeItems;
  private
    class operator Initialize(var s: TGLiteObjectStack);
    class operator Finalize(var s: TGLiteObjectStack);
    class operator Copy(constref aSrc: TGLiteObjectStack; var aDst: TGLiteObjectStack);
  public
  type
    TEnumerator        = TStack.TEnumerator;
    TReverseEnumerator = TStack.TReverseEnumerator;
    TReverse           = TStack.TReverse;

    function  GetEnumerator: TEnumerator;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  Reverse: TReverse;
    function  ToArray: TArray;
    procedure Clear;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure EnsureCapacity(aValue: SizeInt);
    procedure TrimToFit;
    procedure Push(const aValue: T); inline;
    function  Pop: T; inline;
    function  TryPop(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectStack<T: class> = class
  public
  type
    TStack = specialize TGLiteObjectStack<T>;
    PStack = ^TStack;

  strict private
    FStack: TStack;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Push(const aValue: T);
    function  TryPop(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PStack;
    procedure Unlock; inline;
  end;


implementation
{$B-}{$COPERATORS ON}

{ TGStack }

function TGStack.PopItem: T;
begin
  Dec(FCount);
  Result := FItems[ElemCount];
  FItems[ElemCount] := Default(T);
end;

procedure TGStack.Push(const aValue: T);
begin
  CheckInIteration;
  Append(aValue);
end;

function TGStack.PushAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGStack.PushAll(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := AppendEnumerable(e)
  else
    begin
      Result := 0;
      e.Any;
      UpdateLockError;
    end;
end;

function TGStack.Pop: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := PopItem;
end;

function TGStack.TryPop(out aValue: T): Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      aValue := PopItem;
      exit(True);
    end;
  Result := False;
end;

function TGStack.Peek: T;
begin
  CheckEmpty;
  Result := FItems[Pred(ElemCount)];
end;

function TGStack.TryPeek(out aValue: T): Boolean;
begin
  if ElemCount > 0 then
    begin
      aValue := FItems[Pred(ElemCount)];
      exit(True);
    end;
  Result := False;
end;

{ TGObjectStack }

procedure TGObjectStack.DoClear;
var
  I: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    for I := 0 to Pred(ElemCount) do
      FItems[I].Free;
  inherited;
end;

constructor TGObjectStack.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectStack.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectStack.Create(const A: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectStack.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

{ TGThreadStack }

procedure TGThreadStack.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadStack.Create(aStack: IStack);
begin
  System.InitCriticalSection(FLock);
  FStack := aStack;
end;

destructor TGThreadStack.Destroy;
begin
  DoLock;
  try
    FStack._GetRef.Free;
    FStack := nil;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGThreadStack.Clear;
begin
  DoLock;
  try
    FStack.Clear;
  finally
    UnLock;
  end;
end;

procedure TGThreadStack.Push(const aValue: T);
begin
  DoLock;
  try
    FStack.Push(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadStack.TryPop(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPop(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadStack.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadStack.Lock: IStack;
begin
  Result := FStack;
  DoLock;
end;

procedure TGThreadStack.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteStack }

function TGLiteStack.PopItem: T;
begin
  Dec(FBuffer.FCount);
  Result := FBuffer.FItems[Count];
  FBuffer.FItems[Count] := Default(T);
end;

function TGLiteStack.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteStack.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteStack.GetMutableEnumerator: TMutableEnumerator;
begin
  Result := FBuffer.GetMutableEnumerator;
end;

function TGLiteStack.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteStack.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteStack.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

function TGLiteStack.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

procedure TGLiteStack.Clear;
begin
  FBuffer.Clear;
end;

function TGLiteStack.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteStack.NonEmpty: Boolean;
begin
  Result := Count > 0;
end;

procedure TGLiteStack.MakeEmpty;
begin
  FBuffer.MakeEmpty;
end;

procedure TGLiteStack.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteStack.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteStack.Push(const aValue: T);
begin
  FBuffer.PushLast(aValue);
end;

function TGLiteStack.Pop: T;
begin
  FBuffer.CheckEmpty;
  Result := PopItem;
end;

function TGLiteStack.TryPop(out aValue: T): Boolean;
begin
  Result := Count > 0;
  if Result then
    aValue := PopItem;
end;

function TGLiteStack.Peek: T;
begin
  FBuffer.CheckEmpty;
  Result := FBuffer.FItems[Pred(Count)];
end;

function TGLiteStack.TryPeek(out aValue: T): Boolean;
begin
  if Count > 0 then
    begin
      aValue := FBuffer.FItems[Pred(Count)];
      exit(True);
    end;
  Result := False;
end;

function TGLiteStack.PeekItem: PItem;
begin
  FBuffer.CheckEmpty;
  Result := @FBuffer.FItems[Pred(Count)];
end;

function TGLiteStack.TryPeekItem(out aValue: PItem): Boolean;
begin
  if Count > 0 then
    begin
      aValue := @FBuffer.FItems[Pred(Count)];
      exit(True);
    end;
  Result := False;
end;

{ TGLiteThreadStack }

procedure TGLiteThreadStack.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadStack.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadStack.Destroy;
begin
  DoLock;
  try
    Finalize(FStack);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadStack.Clear;
begin
  DoLock;
  try
    FStack.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadStack.Push(const aValue: T);
begin
  DoLock;
  try
    FStack.Push(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadStack.TryPop(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPop(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadStack.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadStack.Lock: PStack;
begin
  Result := @FStack;
  DoLock;
end;

procedure TGLiteThreadStack.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteObjectStack }

function TGLiteObjectStack.GetCapacity: SizeInt;
begin
  Result := FStack.Capacity;
end;

function TGLiteObjectStack.GetCount: SizeInt;
begin
  Result := FStack.Count;
end;

procedure TGLiteObjectStack.CheckFreeItems;
var
  I: Integer;
begin
  if OwnsObjects then
    for I := 0 to Pred(Count) do
      FStack.FBuffer.FItems[I].Free;
end;

class operator TGLiteObjectStack.Initialize(var s: TGLiteObjectStack);
begin
  s.FOwnsObjects := True;
end;

class operator TGLiteObjectStack.Finalize(var s: TGLiteObjectStack);
begin
  s.Clear;
end;

class operator TGLiteObjectStack.Copy(constref aSrc: TGLiteObjectStack; var aDst: TGLiteObjectStack);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FStack := aSrc.FStack;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectStack.GetEnumerator: TEnumerator;
begin
  Result := FStack.GetEnumerator;
end;

function TGLiteObjectStack.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FStack.GetReverseEnumerator;
end;

function TGLiteObjectStack.Reverse: TReverse;
begin
  Result := FStack.Reverse;
end;

function TGLiteObjectStack.ToArray: TArray;
begin
  Result := FStack.ToArray;
end;

procedure TGLiteObjectStack.Clear;
begin
  CheckFreeItems;
  FStack.Clear;
end;

function TGLiteObjectStack.IsEmpty: Boolean;
begin
  Result := FStack.IsEmpty;
end;

function TGLiteObjectStack.NonEmpty: Boolean;
begin
  Result := FStack.NonEmpty;
end;

procedure TGLiteObjectStack.EnsureCapacity(aValue: SizeInt);
begin
  FStack.EnsureCapacity(aValue);
end;

procedure TGLiteObjectStack.TrimToFit;
begin
  FStack.TrimToFit;
end;

procedure TGLiteObjectStack.Push(const aValue: T);
begin
  FStack.Push(aValue);
end;

function TGLiteObjectStack.Pop: T;
begin
  Result := FStack.Pop;
end;

function TGLiteObjectStack.TryPop(out aValue: T): Boolean;
begin
  Result := FStack.TryPop(aValue);
end;

function TGLiteObjectStack.Peek: T;
begin
  Result := FStack.Peek;
end;

function TGLiteObjectStack.TryPeek(out aValue: T): Boolean;
begin
  Result := FStack.TryPeek(aValue);
end;

{ TGLiteThreadObjectStack }

procedure TGLiteThreadObjectStack.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectStack.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadObjectStack.Destroy;
begin
  DoLock;
  try
    Finalize(FStack);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadObjectStack.Clear;
begin
  DoLock;
  try
    FStack.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadObjectStack.Push(const aValue: T);
begin
  DoLock;
  try
    FStack.Push(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectStack.TryPop(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPop(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectStack.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FStack.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectStack.Lock: PStack;
begin
  Result := @FStack;
  DoLock;
end;

procedure TGLiteThreadObjectStack.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

end.

