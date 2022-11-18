{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic queue implementations.                                          *
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
unit lgQueue;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  SysUtils,
  lgUtils,
  lgAbstractContainer;

type

  generic TGQueue<T> = class(specialize TGCustomRingArrayBuffer<T>, specialize IGContainer<T>,
    specialize IGQueue<T>)
  public
    procedure Enqueue(const aValue: T); inline;
    function  EnqueueAll(const a: array of T): SizeInt;
    function  EnqueueAll(e: IEnumerable): SizeInt; inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
  end;

  { TGObjectQueue note:
    TGObjectQueue.Dequeue(or TGObjectQueue.TryDequeue) EXTRACTS object from queue;
    you need to free this object yourself }
  generic TGObjectQueue<T: class> = class(specialize TGQueue<T>)
  private
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

  generic TGThreadQueue<T> = class
  public
  type
    IQueue = specialize IGQueue<T>;

  private
    FQueue: IQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create(aQueue: IQueue);
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: IQueue;
    procedure Unlock; inline;
  end;

  generic TGLiteQueue<T> = record
  private
  type
    TBuffer = specialize TGLiteRingDynBuffer<T>;

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
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  GetMutableEnumerator: TMutableEnumerator; inline;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure MakeEmpty; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(constref aValue: T); inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    function  PeekItem: PItem; inline;
    function  TryPeekItem(out aValue: PItem): Boolean; inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGLiteThreadQueue<T> = class
  public
  type
    TQueue = specialize TGLiteQueue<T>;
    PQueue = ^TQueue;

  strict private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PQueue;
    procedure Unlock; inline;
  end;

  generic TGLiteBlockQueue<T> = class
  public
  type
    TQueue = specialize TGLiteQueue<T>;

  strict private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    FReadAwait: PRtlEvent;
    function  GetCapacity: SizeInt;
    function  GetCount: SizeInt;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  Dequeue: T;
    function  Peek: T;
    function  TryPeek(out aValue: T): Boolean;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGLiteObjectQueue<T: class> = record
  strict private
  type
    TQueue             = specialize TGLiteQueue<T>;
    TEnumerator        = TQueue.TEnumerator;
    TReverseEnumerator = TQueue.TReverseEnumerator;
    TReverse           = TQueue.TReverse;
    TArray             = TQueue.TArray;

  var
    FQueue: TQueue;
    FOwnsObjects: Boolean;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    procedure CheckFreeItems;
    class operator Initialize(var q: TGLiteObjectQueue);
    class operator Finalize(var q: TGLiteObjectQueue);
    class operator Copy(constref aSrc: TGLiteObjectQueue; var aDst: TGLiteObjectQueue);
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(constref aValue: T);
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectQueue<T: class> = class
  public
  type
    TQueue = specialize TGLiteObjectQueue<T>;
    PQueue = ^TQueue;

  private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PQueue;
    procedure Unlock; inline;
  end;

  { TGLiteThreadQueueSL: spinlock based concurrent queue }
  generic TGLiteThreadQueueSL<T> = record
  private
  type
    TBuffer = specialize TGLiteRingDynBuffer<T>;

  public
  type
    TArray = array of T;

  private
    FLock: TSpinLock;
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt;
    function  GetCount: SizeInt;
  public
    function  ToArray: TArray;
    procedure Clear;
    function  IsEmpty: Boolean;
    procedure EnsureCapacity(aValue: SizeInt);
    procedure TrimToFit;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TGLiteThreadBoundQueueSL: spinlock based concurrent bounded queue }
  generic TGLiteThreadBoundQueueSL<T> = record
  strict private
    FBuffer: array of T;
    FTail,
    FCount: SizeInt;
    FLock: TSpinLock;
    function GetCapacity: SizeInt; inline;
    function GetHead: SizeInt; inline;
    function GetCount: SizeInt;
  public
    constructor Create(aSize: SizeInt);
    function Enqueue(constref aValue: T): Boolean;
    function TryDequeue(out aValue: T): Boolean;
    function TryPeek(out aValue: T): Boolean;
    property Count: SizeInt read GetCount;
    property Capacity: SizeInt read GetCapacity;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGQueue }

procedure TGQueue.Enqueue(const aValue: T);
begin
  CheckInIteration;
  Append(aValue);
end;

function TGQueue.EnqueueAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGQueue.EnqueueAll(e: IEnumerable): SizeInt;
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

function TGQueue.Dequeue: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := ExtractHead;
end;

function TGQueue.TryDequeue(out aValue: T): Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      aValue := ExtractHead;
      exit(True);
    end;
  Result := False;
end;

function TGQueue.Peek: T;
begin
  CheckEmpty;
  Result := FItems[Head];
end;

function TGQueue.TryPeek(out aValue: T): Boolean;
begin
  if ElemCount > 0 then
    begin
      aValue := FItems[Head];
      exit(True);
    end;
  Result := False;
end;

{ TGObjectQueue }

procedure TGObjectQueue.DoClear;
var
  I, CurrIdx, c: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    begin
      CurrIdx := Head;
      c := Capacity;
      for I := 1 to ElemCount do
        begin
          FItems[CurrIdx].Free;
          Inc(CurrIdx);
          if CurrIdx = c then
            CurrIdx := 0;
        end;
    end;
  inherited;
end;

constructor TGObjectQueue.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(const A: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

{ TGThreadQueue }

procedure TGThreadQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

procedure TGThreadQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

constructor TGThreadQueue.Create(aQueue: IQueue);
begin
  System.InitCriticalSection(FLock);
  FQueue := aQueue;
end;

destructor TGThreadQueue.Destroy;
begin
  DoLock;
  try
    FQueue._GetRef.Free;
    FQueue := nil;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGThreadQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGThreadQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.Lock: IQueue;
begin
  Result := FQueue;
  DoLock;
end;

{ TGLiteQueue }

function TGLiteQueue.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteQueue.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteQueue.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteQueue.GetMutableEnumerator: TMutableEnumerator;
begin
  Result := FBuffer.GetMutableEnumerator;
end;

function TGLiteQueue.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteQueue.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteQueue.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteQueue.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteQueue.MakeEmpty;
begin
  FBuffer.MakeEmpty;
end;

function TGLiteQueue.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteQueue.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteQueue.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteQueue.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteQueue.Enqueue(constref aValue: T);
begin
  FBuffer.PushLast(aValue);
end;

function TGLiteQueue.Dequeue: T;
begin
  Result := FBuffer.PopFirst;
end;

function TGLiteQueue.TryDequeue(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPopFirst(aValue);
end;

function TGLiteQueue.Peek: T;
begin
  Result := FBuffer.PeekFirst;
end;

function TGLiteQueue.TryPeek(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPeekFirst(aValue);
end;

function TGLiteQueue.PeekItem: PItem;
begin
  Result := FBuffer.PeekFirstItem;
end;

function TGLiteQueue.TryPeekItem(out aValue: PItem): Boolean;
begin
  Result := FBuffer.TryPeekFirstItem(aValue);
end;

{ TGLiteThreadQueue }

procedure TGLiteThreadQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

procedure TGLiteThreadQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

constructor TGLiteThreadQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadQueue.Destroy;
begin
  DoLock;
  try
    Finalize(FQueue);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.Lock: PQueue;
begin
  Result := @FQueue;
  DoLock;
end;

{ TGLiteBlockQueue }

function TGLiteBlockQueue.GetCapacity: SizeInt;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FQueue.Capacity;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGLiteBlockQueue.GetCount: SizeInt;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FQueue.Count;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

constructor TGLiteBlockQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteBlockQueue.Destroy;
begin
  System.EnterCriticalSection(FLock);
  try
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    Finalize(FQueue);
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteBlockQueue.AfterConstruction;
begin
  inherited;
  FReadAwait  := System.RtlEventCreate;
end;

procedure TGLiteBlockQueue.Clear;
begin
  System.EnterCriticalSection(FLock);
  try
    FQueue.Clear;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TGLiteBlockQueue.Enqueue(constref aValue: T);
begin
  System.EnterCriticalSection(FLock);
  try
    FQueue.Enqueue(aValue);
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGLiteBlockQueue.Dequeue: T;
begin
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    Result := FQueue.Dequeue;
    if FQueue.NonEmpty then
      System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGLiteBlockQueue.Peek: T;
begin
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    Result := FQueue.Peek;
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGLiteBlockQueue.TryPeek(out aValue: T): Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FQueue.TryPeek(aValue);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TGLiteObjectQueue }

function TGLiteObjectQueue.GetCapacity: SizeInt;
begin
  Result := FQueue.Capacity;
end;

function TGLiteObjectQueue.GetCount: SizeInt;
begin
  Result := FQueue.Count;
end;

procedure TGLiteObjectQueue.CheckFreeItems;
var
  v: T;
begin
  if OwnsObjects and (Count > 0) then
    for v in FQueue do
      v.Free;
end;

class operator TGLiteObjectQueue.Initialize(var q: TGLiteObjectQueue);
begin
  q.FOwnsObjects := True;
end;

class operator TGLiteObjectQueue.Finalize(var q: TGLiteObjectQueue);
begin
  q.CheckFreeItems;
  q.FQueue.Clear;
end;

class operator TGLiteObjectQueue.Copy(constref aSrc: TGLiteObjectQueue; var aDst: TGLiteObjectQueue);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FQueue := aSrc.FQueue;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectQueue.GetEnumerator: TEnumerator;
begin
  Result := FQueue.GetEnumerator;
end;

function TGLiteObjectQueue.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FQueue.GetReverseEnumerator;
end;

function TGLiteObjectQueue.Reverse: TReverse;
begin
  Result := FQueue.Reverse;
end;

function TGLiteObjectQueue.ToArray: TArray;
begin
  Result := FQueue.ToArray;
end;

procedure TGLiteObjectQueue.Clear;
begin
  CheckFreeItems;
  FQueue.Clear;
end;

function TGLiteObjectQueue.IsEmpty: Boolean;
begin
  Result := FQueue.IsEmpty;
end;

function TGLiteObjectQueue.NonEmpty: Boolean;
begin
  Result := FQueue.NonEmpty;
end;

procedure TGLiteObjectQueue.EnsureCapacity(aValue: SizeInt);
begin
  FQueue.EnsureCapacity(aValue);
end;

procedure TGLiteObjectQueue.TrimToFit;
begin
  FQueue.TrimToFit;
end;

procedure TGLiteObjectQueue.Enqueue(constref aValue: T);
begin
  FQueue.Enqueue(aValue);
end;

function TGLiteObjectQueue.Dequeue: T;
begin
  Result := FQueue.Dequeue;
end;

function TGLiteObjectQueue.TryDequeue(out aValue: T): Boolean;
begin
  Result := FQueue.TryDequeue(aValue);
end;

function TGLiteObjectQueue.Peek: T;
begin
  Result := FQueue.Peek;
end;

function TGLiteObjectQueue.TryPeek(out aValue: T): Boolean;
begin
  Result := FQueue.TryPeek(aValue);
end;

{ TGLiteThreadObjectQueue }

procedure TGLiteThreadObjectQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

procedure TGLiteThreadObjectQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

destructor TGLiteThreadObjectQueue.Destroy;
begin
  DoLock;
  try
    Finalize(FQueue);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadObjectQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadObjectQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.Lock: PQueue;
begin
  Result := @FQueue;
  DoLock;
end;

{ TGLiteThreadQueueSL }

function TGLiteThreadQueueSL.GetCapacity: SizeInt;
begin
  FLock.Lock;
  try
    Result := FBuffer.Capacity;
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadQueueSL.GetCount: SizeInt;
begin
  FLock.Lock;
  try
    Result := FBuffer.FCount;
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadQueueSL.ToArray: TArray;
begin
  FLock.Lock;
  try
    Result := FBuffer.ToArray;
  finally
    FLock.Unlock;
  end;
end;

procedure TGLiteThreadQueueSL.Clear;
begin
  FLock.Lock;
  try
    FBuffer.Clear;
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadQueueSL.IsEmpty: Boolean;
begin
  FLock.Lock;
  try
    Result := FBuffer.FCount = 0;
  finally
    FLock.Unlock;
  end;
end;

procedure TGLiteThreadQueueSL.EnsureCapacity(aValue: SizeInt);
begin
  FLock.Lock;
  try
    FBuffer.EnsureCapacity(aValue);
  finally
    FLock.Unlock;
  end;
end;

procedure TGLiteThreadQueueSL.TrimToFit;
begin
  FLock.Lock;
  try
    FBuffer.TrimToFit;
  finally
    FLock.Unlock;
  end;
end;

procedure TGLiteThreadQueueSL.Enqueue(constref aValue: T);
begin
  FLock.Lock;
  try
    FBuffer.PushLast(aValue);
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadQueueSL.TryDequeue(out aValue: T): Boolean;
begin
  FLock.Lock;
  try
    Result := FBuffer.TryPopFirst(aValue);
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadQueueSL.TryPeek(out aValue: T): Boolean;
begin
  FLock.Lock;
  try
    Result := FBuffer.TryPeekFirst(aValue);
  finally
    FLock.Unlock;
  end;
end;

{ TLiteThreadBoundQueueSL }

function TGLiteThreadBoundQueueSL.GetCapacity: SizeInt;
begin
  Result := System.Length(FBuffer);
end;

function TGLiteThreadBoundQueueSL.GetHead: SizeInt;
begin
  Result := FTail - FCount;
  if Result < 0 then
    Result += Capacity;
end;

function TGLiteThreadBoundQueueSL.GetCount: SizeInt;
begin
  FLock.Lock;
  try
    Result := FCount;
  finally
    FLock.Unlock;
  end;
end;

constructor TGLiteThreadBoundQueueSL.Create(aSize: SizeInt);
begin
  if aSize < DEFAULT_CONTAINER_CAPACITY then
    aSize := DEFAULT_CONTAINER_CAPACITY;
  System.SetLength(FBuffer, aSize);
  FTail := 0;
  FCount := 0;
end;

function TGLiteThreadBoundQueueSL.Enqueue(constref aValue: T): Boolean;
begin
  FLock.Lock;
  try
    Result := FCount < Capacity;
    if Result then
      begin
        FBuffer[FTail] := aValue;
        Inc(FCount);
        if FTail = Capacity then
          FTail := 0;
      end;
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadBoundQueueSL.TryDequeue(out aValue: T): Boolean;
var
  h: SizeInt;
begin
  FLock.Lock;
  try
    Result := FCount > 0;
    if Result then
      begin
        h := GetHead;
        aValue := FBuffer[h];
        Dec(FCount);
        FBuffer[h] := Default(T);
      end;
  finally
    FLock.Unlock;
  end;
end;

function TGLiteThreadBoundQueueSL.TryPeek(out aValue: T): Boolean;
begin
  FLock.Lock;
  try
    Result := FCount > 0;
    if Result then
      aValue := FBuffer[GetHead];
  finally
    FLock.Unlock;
  end;
end;

end.

