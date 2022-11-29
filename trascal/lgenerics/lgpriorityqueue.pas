{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic prority queue implementations.                                  *
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
unit lgPriorityQueue;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  lgHelpers,
  lgAbstractContainer,
  lgStrConst;

type

  { TGCustomBinHeap: abstract ancestor class of priority queue with queue interface on top of binary heap }
  generic TGCustomBinHeap<T> = class abstract(specialize TGCustomArrayContainer<T>, specialize IGQueue<T>)
  protected
    procedure BuildHeap; virtual; abstract;
    procedure FixHeap(aFrom: SizeInt); inline;
    procedure SiftDown; virtual; abstract;
    procedure FloatUp(aIndex: SizeInt); virtual; abstract;
    function  DequeueItem: T;
    procedure FixAfterEnqueue(aOldCount: SizeInt); inline;
  public
    procedure AfterConstruction; override;
    procedure Enqueue(const aValue: T);   // O(logN)
    function  EnqueueAll(const a: array of T): SizeInt;
    function  EnqueueAll(e: IEnumerable): SizeInt;
    function  Dequeue: T;                 // O(logN)
    function  TryDequeue(out aValue: T): Boolean;
    function  Peek: T;                    // O(1)
    function  TryPeek(out aValue: T): Boolean;
  end;

  { TGBaseBinHeap implements maximizing priority queue with queue interface;
      functor TCmpRel (comparision relation) must provide
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseBinHeap<T, TCmpRel> = class(specialize TGCustomBinHeap<T>)
  protected
    procedure BuildHeap; override;
    procedure SiftDown; override;
    procedure FloatUp(aIndex: SizeInt);  override;
    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
  end;

  { TGBinHeap assumes that type T implements TCmpRel}
  generic TGBinHeap<T> = class(specialize TGBaseBinHeap<T, T>);

  { TGObjectBinHeap implements maximizing priority queue with queue interface;
      TGObjectBinHeap.Dequeue(or TryDequeue) EXTRACTS object from queue,
      you need to free this object yourself }
  generic TGObjectBinHeap<T: class; TCmpRel> = class(specialize TGBaseBinHeap<T, TCmpRel>)
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

  { TGObjBinHeap assumes that class T implements TCmpRel}
  generic TGObjBinHeap<T: class> = class(specialize TGObjectBinHeap<T, T>);

  generic TGComparableBinHeap<T> = class(specialize TGCustomBinHeap<T>)
  protected
    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
  end;

  { TGComparableBinHeapMax: maximizing priority queue with queue interface,
    it assumes that type T has defined comparison operator < }
  generic TGComparableBinHeapMax<T> = class(specialize TGComparableBinHeap<T>)
  protected
    procedure BuildHeap; override;
    procedure SiftDown; override;
    procedure FloatUp(aIndex: SizeInt); override;
  end;

  { TGComparableBinHeapMin: minimizing priority queue with queue interface,
    it assumes that type T has defined comparison operator < }
  generic TGComparableBinHeapMin<T> = class(specialize TGComparableBinHeap<T>)
  protected
    procedure BuildHeap; override;
    procedure SiftDown; override;
    procedure FloatUp(aIndex: SizeInt); override;
  end;

  { TGRegularBinHeap: maximizing priority queue with queue interface and regular comparator }
  generic TGRegularBinHeap<T> = class(specialize TGCustomBinHeap<T>)
  private
    FLess: TLess;
  protected
    procedure BuildHeap; override;
    procedure SiftDown; override;
    procedure FloatUp(aIndex: SizeInt); override;
  public
    constructor Create;
    constructor Create(c: TLess);
    constructor Create(aCapacity: SizeInt; c: TLess);
    constructor Create(const A: array of T; c: TLess);
    constructor Create(e: IEnumerable; c: TLess);
    function Comparator: TLess; inline;
  end;

  { TGDelegatedBinHeap: maximizing priority queue with queue interface and delegated comparator }
  generic TGDelegatedBinHeap<T> = class(specialize TGCustomBinHeap<T>)
  private
    FLess: TOnLess;
  protected
    procedure BuildHeap; override;
    procedure SiftDown; override;
    procedure FloatUp(aIndex: SizeInt); override;
  public
  type
    TComparator = TOnLess;
    constructor Create;
    constructor Create(c: TComparator);
    constructor Create(aCapacity: SizeInt; c: TComparator);
    constructor Create(const A: array of T; c: TComparator);
    constructor Create(e: IEnumerable; c: TComparator);
    function Comparator: TOnLess; inline;
  end;

  { TGLiteBinHeap implements maximizing priority queue with queue interface;
      functor TCmpRel (comparision relation) must provide
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGLiteBinHeap<T, TCmpRel> = record
  public
  type
    TBuffer     = specialize TGLiteDynBuffer<T>;
    TEnumerator = TBuffer.TEnumerator;
    TReverse    = TBuffer.TReverse;
    TArray      = TBuffer.TArray;

  strict private
  type
    TFake = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    procedure BuildHeap;
    procedure SiftDown;
    procedure FloatUp(aIndex: SizeInt);
    function  DequeueItem: T;
    property  Items: TBuffer.TArray read FBuffer.FItems;
    class function DoCompare(const L, R: T): Boolean; static;
  public
  type
    TLess = specialize TGLessCompare<T>;
    function  Comparator: TLess; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure Modified; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(const aValue: T); inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGLiteThreadBinHeap<T, TCmpRel> = class
  public
  type
    TQueue = specialize TGLiteBinHeap<T, TCmpRel>;
    PQueue = ^TQueue;

  strict private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(const aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PQueue;
    procedure Unlock; inline;
  end;

  { TGLiteComparableBinHeapMin implements minimizing priority queue with queue interface;
    it assumes that type T has defined comparison operator < }
  generic TGLiteComparableBinHeapMin<T> = record
  public
  type
    TBuffer     = specialize TGLiteDynBuffer<T>;
    TEnumerator = TBuffer.TEnumerator;
    TReverse    = TBuffer.TReverse;
    TArray      = TBuffer.TArray;
  strict private
  type
    TFake = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    procedure BuildHeap;
    procedure SiftDown;
    procedure FloatUp(aIndex: SizeInt);
    function  DequeueItem: T;
    class function DoCompare(const L, R: T): Boolean; static;
  public
  type
    TLess = specialize TGLessCompare<T>;
    function  Comparator: TLess; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure Modified; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(const aValue: T); inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  THandle = LGUtils.THandle;

  { TGCustomPairingHeap: abstract ancestor class to implement priority queue on top of pairing heap }
  generic TGCustomPairingHeap<T> = class abstract(specialize TGAbstractContainer<T>, specialize IGQueue<T>,
    specialize IGPriorityQueue<T>)
  public
  type
    TCustomPairingHeap = specialize TGCustomPairingHeap<T>;
    IPriorityQueue     = specialize IGPriorityQueue<T>;

  protected
  type
    PNode = ^TNode;
    TNode = record
      Child,
      Sibling,
      Prev: PNode;
      Data: T;
      procedure AddChild(aNode: PNode);
      procedure ClearLinks; inline;
      function  Successor: PNode;
      function  Predecessor: PNode;
    end;

    TEnumerator = class(TContainerEnumerator)
    private
      FCurrNode,
      FLeftmost: PNode;
      FInCycle: Boolean;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(aHeap: TCustomPairingHeap);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnum = class(TContainerEnumerable)
    protected
      FCurrNode,
      FRightmost: PNode;
      FInCycle: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(aHeap: TCustomPairingHeap);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FRoot: PNode;
    FCount: SizeInt;
    procedure CheckEmpty; inline;
    function  GetCount: SizeInt; override;
    function  GetCapacity: SizeInt; override;
    procedure CopyItems(aBuffer: PItem); override;
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoClear; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    function  NewNode(const aValue: T): PNode;
    procedure DisposeNode(aNode: PNode); inline;
    procedure RemoveNodeWithChilds(aNode: PNode);
    procedure ClearTree;
    function  FindLeftmost: PNode;
    function  FindRightmost: PNode;
    function  EnqueueArray(const a: array of T): SizeInt;
    function  EnqueueContainer(c: TSpecContainer): SizeInt;
    function  EnqueueEnum(e: IEnumerable): SizeInt;
    function  DoEnqueue(const aValue: T): PNode; virtual; abstract;
    procedure DoUpdate(aNode: PNode; const aValue: T); virtual; abstract;
    function  DoRemove(aNode: PNode): T; virtual; abstract;
    function  DoDequeue: T; virtual; abstract;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; virtual; abstract;
    class procedure CutNode(aNode: PNode); static;
    class function  Ptr2Handle(aNode: PNode): THandle; static; inline;
    class function  Handle2Ptr(h: THandle): PNode; static; inline;
  public
    destructor Destroy; override;
    function  Reverse: IEnumerable; override;
    procedure Enqueue(const aValue: T); inline;             // O(1)
    function  EnqueueAll(const a: array of T): SizeInt;
    function  EnqueueAll(e: IEnumerable): SizeInt;
    function  Dequeue: T;                                   // amortized O(logN)
    function  TryDequeue(out aValue: T): Boolean;
    function  Peek: T;                                      // O(1)
    function  TryPeek(out aValue: T): Boolean;
    function  Insert(const aValue: T): THandle; inline;     // O(1)
    function  PeekHandle: THandle; inline;                  // O(1)
    function  TryPeekHandle(out aHandle: THandle): Boolean; inline;
    function  ValueOf(aHandle: THandle): T; inline;
    procedure Update(aHandle: THandle; const aValue: T); inline; //O(1) IncreaseKey
    function  Remove(aHandle: THandle): T;                  // amortized O(logN)
  { note: after Merge all handles from aQueue will remain valid if aQueue has same ClassType }
    function  Merge(aQueue: IPriorityQueue): SizeInt;       // O(1) if aQueue has same ClassType
  end;

  { TGBasePairingHeap implements maximizing priority queue;
      functor TCmpRel (comparision relation) must provide
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBasePairingHeap<T, TCmpRel> = class(specialize TGCustomPairingHeap<T>)
  protected
    procedure RootMerge(aNode: PNode); inline;
    procedure DoExtract(aNode: PNode);
    function  DoEnqueue(const aValue: T): PNode; override;
    procedure DoUpdate(aNode: PNode; const aValue: T); override;
    function  DoRemove(aNode: PNode): T; override;
    function  DoDequeue: T; override;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; override;
    class function DoMerge(L, R: PNode): PNode; static;
    class function TwoPassMerge(aNode: PNode): PNode; static;
    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
    constructor Create(const A: array of T); overload;
    constructor Create(e: IEnumerable); overload;
  end;

  { TGPairingHeap assumes that type T implements TCmpRel}
  generic TGPairingHeap<T> = class(specialize TGBasePairingHeap<T, T>);

  generic TGComparablePairHeap<T> = class(specialize TGCustomPairingHeap<T>)
  protected
    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
  end;

  { TGComparablePairHeapMax: maximizing priority queue, it assumes
    that type T has defined comparison operator < }
  generic TGComparablePairHeapMax<T> = class(specialize TGComparablePairHeap<T>)
  protected
    procedure RootMerge(aNode: PNode); inline;
    procedure DoExtract(aNode: PNode);
    function  DoEnqueue(const aValue: T): PNode; override;
    procedure DoUpdate(aNode: PNode; const aValue: T); override;
    function  DoRemove(aNode: PNode): T; override;
    function  DoDequeue: T; override;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; override;
    class function DoMerge(L, R: PNode): PNode; static;
    class function TwoPassMerge(aNode: PNode): PNode; static;
  public
    constructor Create(const A: array of T); overload;
    constructor Create(e: IEnumerable); overload;
  end;

  { TGComparablePairHeapMin: minimizing priority queue, it assumes
    that type T has defined comparison operator < }
  generic TGComparablePairHeapMin<T> = class(specialize TGComparablePairHeap<T>)
  protected
    procedure RootMerge(aNode: PNode); inline;
    procedure DoExtract(aNode: PNode);
    function  DoEnqueue(const aValue: T): PNode; override;
    procedure DoUpdate(aNode: PNode; const aValue: T); override;
    function  DoRemove(aNode: PNode): T; override;
    function  DoDequeue: T; override;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; override;
    class function DoMerge(L, R: PNode): PNode; static;
    class function TwoPassMerge(aNode: PNode): PNode; static;
  public
    constructor Create(const A: array of T); overload;
    constructor Create(e: IEnumerable); overload;
  end;

  { TGRegularPairHeap: maximizing priority queue with regular comparator }
  generic TGRegularPairHeap<T> = class(specialize TGCustomPairingHeap<T>)
  protected
    FLess: TLess;
    function  DoMerge(L, R: PNode): PNode;
    procedure RootMerge(aNode: PNode); inline;
    function  TwoPassMerge(aNode: PNode): PNode;
    procedure DoExtract(aNode: PNode);
    function  DoEnqueue(const aValue: T): PNode; override;
    procedure DoUpdate(aNode: PNode; const aValue: T); override;
    function  DoRemove(aNode: PNode): T; override;
    function  DoDequeue: T; override;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; override;
  public
    constructor Create;
    constructor Create(c: TLess);
    constructor Create(const A: array of T; c: TLess);
    constructor Create(e: IEnumerable; c: TLess);
    function Comparator: TLess; inline;
  end;

  { TGDelegatedPairHeap: maximizing priority queue with delegated comparator }
  generic TGDelegatedPairHeap<T> = class(specialize TGCustomPairingHeap<T>)
  protected
    FLess: TOnLess;
    function  DoMerge(L, R: PNode): PNode;
    procedure RootMerge(aNode: PNode); inline;
    function  TwoPassMerge(aNode: PNode): PNode;
    procedure DoExtract(aNode: PNode);
    function  DoEnqueue(const aValue: T): PNode; override;
    procedure DoUpdate(aNode: PNode; const aValue: T); override;
    function  DoRemove(aNode: PNode): T; override;
    function  DoDequeue: T; override;
    function  DoMergeHeap(ph: TCustomPairingHeap): SizeInt; override;
  public
    constructor Create;
    constructor Create(c: TOnLess);
    constructor Create(const A: array of T; c: TOnLess);
    constructor Create(e: IEnumerable; c: TOnLess);
    function Comparator: TOnLess; inline;
  end;

  { TGLitePairingHeap implements maximizing priority queue;
      functor TCmpRel (comparison relation) must provide
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGLitePairingHeap<T, TCmpRel> = record
  private
  type
    PGLitePairingHeap = ^TGLitePairingHeap;

    PNode = ^TNode;
    TNode = record
      Child,
      Sibling,
      Prev: PNode;
      Data: T;
      procedure AddChild(aNode: PNode); inline;
      procedure ClearLinks; inline;
      function  Successor: PNode;
      function  Predecessor: PNode;
    end;

  public
  type
    TArray = array of T;
    PItem  = ^T;

    TEnumerator = record
    private
      FCurrNode,
      FLeftmost: PNode;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrNode,
      FRightmost: PNode;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FHeap: PGLitePairingHeap;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  private
    FRoot: PNode;
    FCount: SizeInt;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  FindLeftmost: PNode;
    function  FindRightmost: PNode;
    procedure RemoveNodeWithChilds(aNode: PNode);
    procedure ClearTree;
    function  NewNode(const aValue: T): PNode;
    procedure DisposeNode(aNode: PNode);
    procedure RootMerge(aNode: PNode); inline;
    function  DequeueItem: T;
    procedure UpdateNode(aNode: PNode; const aValue: T);
    procedure ExtractNode(aNode: PNode);
    function  RemoveNode(aNode: PNode): T;
    procedure CheckEmpty; inline;
    procedure AccessEmptyError;
    class operator  Initialize(var h: TGLitePairingHeap);
    class operator  Finalize(var h: TGLitePairingHeap);
    class operator  Copy(constref aSrc: TGLitePairingHeap; var aDst: TGLitePairingHeap);
    class operator  AddRef(var h: TGLitePairingHeap);
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static;
    class function  DoCompare(const L, R: T): Boolean; static;
    class function  Ptr2Handle(aNode: PNode): THandle; static; inline;
    class function  Handle2Ptr(h: THandle): PNode; static; inline;
  public
  type
    TLess = specialize TGLessCompare<T>;
    function  Comparator: TLess;
    function  GetEnumerator: TEnumerator;
    function  Reverse: TReverse;
    function  ToArray: TArray;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Enqueue(const aValue: T);                     // O(1)
    function  Dequeue: T;                                   // amortized O(logN)
    function  TryDequeue(out aValue: T): Boolean;
    function  Peek: T;                                      // O(1)
    function  TryPeek(out aValue: T): Boolean;
    function  Insert(const aValue: T): THandle; inline;     // O(1)
    function  PeekHandle: THandle; inline;                  // O(1)
    function  TryPeekHandle(out aValue: THandle): Boolean; inline;
    function  ValueOf(aHandle: THandle): T; inline;
    procedure Update(aHandle: THandle; const aValue: T); inline; //O(1)              IncreaseKey
                                                                 //amortized O(logN) DecreaseKey
    function  Remove(aHandle: THandle): T;                  // amortized O(logN)
  { note: after Merge all handles from aHeap will remain valid }
    function  Merge(var aHeap: TGLitePairingHeap): SizeInt; // O(1)
    property  Count: SizeInt read FCount;
  end;

  { TGLiteComparablePairHeapMin implements minimizing priority queue;
    it assumes that type T has defined comparison operator < }
  generic TGLiteComparablePairHeapMin<T> = record
  private
  type
    PGLitePairingHeap = ^TGLiteComparablePairHeapMin;

    PNode = ^TNode;
    TNode = record
      Child,
      Sibling,
      Prev: PNode;
      Data: T;
      procedure AddChild(aNode: PNode); inline;
      procedure ClearLinks; inline;
      function  Successor: PNode;
      function  Predecessor: PNode;
    end;


  public
  type
    TArray = array of T;
    PItem  = ^T;

    TEnumerator = record
    private
      FCurrNode,
      FLeftmost: PNode;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrNode,
      FRightmost: PNode;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FHeap: PGLitePairingHeap;
    public
      function GetEnumerator: TReverseEnumerator;
    end;

  private
    FRoot: PNode;
    FCount: SizeInt;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  FindLeftmost: PNode;
    function  FindRightmost: PNode;
    procedure RemoveNodeWithChilds(aNode: PNode);
    procedure ClearTree;
    function  NewNode(const aValue: T): PNode; inline;
    procedure DisposeNode(aNode: PNode);
    procedure RootMerge(aNode: PNode); inline;
    function  DequeueItem: T;
    procedure UpdateNode(aNode: PNode; const aValue: T); inline;
    procedure ExtractNode(aNode: PNode);
    function  RemoveNode(aNode: PNode): T;
    procedure CheckEmpty; inline;
    procedure AccessEmptyError;
    class operator  Initialize(var h: TGLiteComparablePairHeapMin);
    class operator  Finalize(var h: TGLiteComparablePairHeapMin);
    class operator  Copy(constref aSrc: TGLiteComparablePairHeapMin; var aDst: TGLiteComparablePairHeapMin);
    class operator  AddRef(var h: TGLiteComparablePairHeapMin);
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static;
    class function  DoCompare(const L, R: T): Boolean; static;
    class function  Ptr2Handle(aNode: PNode): THandle; static; inline;
    class function  Handle2Ptr(h: THandle): PNode; static; inline;
  public
  type
    TLess = specialize TGLessCompare<T>;
    function  Comparator: TLess;
    function  GetEnumerator: TEnumerator;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Enqueue(const aValue: T);                     // O(1)
    function  Dequeue: T;                                   // amortized O(logN)
    function  TryDequeue(out aValue: T): Boolean;
    function  Peek: T;                                      // O(1)
    function  TryPeek(out aValue: T): Boolean;
    function  Insert(const aValue: T): THandle; inline;     // O(1)
    function  PeekHandle: THandle; inline;                  // O(1)
    function  TryPeekHandle(out aValue: THandle): Boolean; inline;
    function  ValueOf(aHandle: THandle): T; inline;
    procedure Update(aHandle: THandle; const aValue: T); inline; //O(1)              DecreaseKey
                                                                 //amortized O(logN) IncreaseKey
    function  Remove(aHandle: THandle): T;                  // amortized O(logN)
  { note: after Merge all handles from aHeap will remain valid }
    function  Merge(var aHeap: TGLiteComparablePairHeapMin): SizeInt;// O(1)
    property  Count: SizeInt read FCount;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGCustomBinHeap }

procedure TGCustomBinHeap.FixHeap(aFrom: SizeInt);
begin
  for aFrom := aFrom to Pred(ElemCount) do
    FloatUp(aFrom);
end;

function TGCustomBinHeap.DequeueItem: T;
begin
  Result := FItems[0];
  Dec(FCount);
  if ElemCount > 0 then
    begin
      FItems[0] := FItems[ElemCount];
      FItems[ElemCount] := Default(T);
      SiftDown;
    end
  else
    FItems[0] := Default(T);
end;

procedure TGCustomBinHeap.FixAfterEnqueue(aOldCount: SizeInt);
begin
  if aOldCount > 0 then
    FixHeap(aOldCount)
  else
    BuildHeap;
end;

procedure TGCustomBinHeap.AfterConstruction;
begin
  inherited;
  if ElemCount > 1 then
    BuildHeap;
end;

procedure TGCustomBinHeap.Enqueue(const aValue: T);
var
  InsertPos: SizeInt;
begin
  CheckInIteration;
  InsertPos := ElemCount;
  ItemAdding;
  FItems[InsertPos] := aValue;
  Inc(FCount);
  if InsertPos > 0 then
    FloatUp(InsertPos);
end;

function TGCustomBinHeap.EnqueueAll(const a: array of T): SizeInt;
var
  OldCount: SizeInt;
begin
  CheckInIteration;
  OldCount := ElemCount;
  Result := AppendArray(a);
  if Result > 0 then
    FixAfterEnqueue(OldCount);
end;

function TGCustomBinHeap.EnqueueAll(e: IEnumerable): SizeInt;
var
  OldCount: SizeInt;
begin
  if not InIteration then
    begin
      OldCount := ElemCount;
      Result := AppendEnumerable(e);
      if Result > 0 then
        FixAfterEnqueue(OldCount);
    end
  else
    begin
      Result := 0;
      e.Any;
      UpdateLockError;
    end;
end;

function TGCustomBinHeap.Dequeue: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := DequeueItem;
end;

function TGCustomBinHeap.TryDequeue(out aValue: T): Boolean;
begin
  Result := not InIteration and (ElemCount > 0);
  if Result then
    aValue := DequeueItem;
end;

function TGCustomBinHeap.Peek: T;
begin
  CheckEmpty;
  Result := FItems[0];
end;

function TGCustomBinHeap.TryPeek(out aValue: T): Boolean;
begin
  Result := ElemCount > 0;
  if Result then
    aValue := FItems[0];
end;

{ TGBaseBinHeap }

procedure TGBaseBinHeap.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if ElemCount > 1 then
    begin
      HighIdx := Pred(ElemCount);
      for I := Pred(ElemCount shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if(Succ(NextIdx) <= HighIdx) and TCmpRel.Less(FItems[NextIdx], FItems[Succ(NextIdx)])then
                Inc(NextIdx);
              if not TCmpRel.Less(T(v), FItems[NextIdx]) then
                break;
              TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGBaseBinHeap.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(ElemCount);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if(Succ(NextIdx) <= HighIdx) and TCmpRel.Less(FItems[NextIdx], FItems[Succ(NextIdx)]) then
            Inc(NextIdx);
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and TCmpRel.Less(FItems[NextIdx], T(v)) do
        begin
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FItems[CurrIdx]) := v;
    end;
end;

procedure TGBaseBinHeap.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  ParentIdx := Pred(aIndex) shr 1;
  v := TFake(FItems[aIndex]);
  while(aIndex > 0) and TCmpRel.Less(FItems[ParentIdx], T(v)) do
    begin
      TFake(FItems[aIndex]) := TFake(FItems[ParentIdx]);
      aIndex := ParentIdx;
      ParentIdx := Pred(ParentIdx) shr 1;
    end;
  TFake(FItems[aIndex]) := v;
end;

class function TGBaseBinHeap.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

class function TGBaseBinHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

{ TGObjectBinHeap }

procedure TGObjectBinHeap.DoClear;
var
  I: SizeInt;
begin
  if OwnsObjects then
    for I := 0 to Pred(ElemCount) do
      FItems[I].Free;
  inherited;
end;

constructor TGObjectBinHeap.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectBinHeap.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectBinHeap.Create(const A: array of T; aOwnsObjects: Boolean = True);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectBinHeap.Create(e: IEnumerable; aOwnsObjects: Boolean = True);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

{ TGComparableBinHeapMax }

procedure TGComparableBinHeapMax.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if ElemCount > 1 then
    begin
      HighIdx := Pred(ElemCount);
      for I := Pred(ElemCount shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if(Succ(NextIdx) <= HighIdx) and (FItems[NextIdx] < FItems[Succ(NextIdx)])then
                Inc(NextIdx);
              if not (T(v) < FItems[NextIdx]) then
                break;
              TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGComparableBinHeapMax.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(ElemCount);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if (Succ(NextIdx) <= HighIdx) and (FItems[NextIdx] < FItems[Succ(NextIdx)]) then
            Inc(NextIdx);
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and (FItems[NextIdx] < T(v)) do
        begin
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FItems[CurrIdx]) := v;
    end;
end;

procedure TGComparableBinHeapMax.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  ParentIdx := Pred(aIndex) shr 1;
  v := TFake(FItems[aIndex]);
  while (aIndex > 0) and (FItems[ParentIdx] < T(v)) do
    begin
      TFake(FItems[aIndex]) := TFake(FItems[ParentIdx]);
      aIndex := ParentIdx;
      ParentIdx := Pred(ParentIdx) shr 1;
    end;
  TFake(FItems[aIndex]) := v;
end;

{ TGComparableBinHeap }

class function TGComparableBinHeap.DoCompare(const L, R: T): Boolean;
begin
  Result := L < R;
end;

class function TGComparableBinHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

{ TGComparableBinHeapMin }

procedure TGComparableBinHeapMin.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if ElemCount > 1 then
    begin
      HighIdx := Pred(ElemCount);
      for I := Pred(ElemCount shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if(Succ(NextIdx) <= HighIdx) and (FItems[Succ(NextIdx)] < FItems[NextIdx])then
                Inc(NextIdx);
              if not (FItems[NextIdx] < T(v)) then
                break;
              TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGComparableBinHeapMin.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(ElemCount);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if (Succ(NextIdx) <= HighIdx) and (FItems[Succ(NextIdx)] < FItems[NextIdx]) then
            Inc(NextIdx);
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and (T(v) < FItems[NextIdx]) do
        begin
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FItems[CurrIdx]) := v;
    end;
end;

procedure TGComparableBinHeapMin.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  ParentIdx := Pred(aIndex) shr 1;
  v := TFake(FItems[aIndex]);
  while (aIndex > 0) and (T(v) < FItems[ParentIdx]) do
    begin
      TFake(FItems[aIndex]) := TFake(FItems[ParentIdx]);
      aIndex := ParentIdx;
      ParentIdx := Pred(ParentIdx) shr 1;
    end;
  TFake(FItems[aIndex]) := v;
end;

{ TGRegularBinHeap }

procedure TGRegularBinHeap.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if ElemCount > 1 then
    begin
      HighIdx := Pred(ElemCount);
      for I := Pred(ElemCount shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if (Succ(NextIdx) <= HighIdx) and FLess(FItems[NextIdx], FItems[Succ(NextIdx)]) then
                Inc(NextIdx);
              if not FLess(T(v), FItems[NextIdx]) then
                break;
              TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGRegularBinHeap.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(ElemCount);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if(Succ(NextIdx) <= HighIdx) and FLess(FItems[NextIdx], FItems[Succ(NextIdx)]) then
            Inc(NextIdx);
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and FLess(FItems[NextIdx], T(v)) do
        begin
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FItems[CurrIdx]) := v;
    end;
end;

procedure TGRegularBinHeap.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  ParentIdx := Pred(aIndex) shr 1;
  v := TFake(FItems[aIndex]);
  while(aIndex > 0) and FLess(FItems[ParentIdx], T(v)) do
    begin
      TFake(FItems[aIndex]) := TFake(FItems[ParentIdx]);
      aIndex := ParentIdx;
      ParentIdx := Pred(ParentIdx) shr 1;
    end;
  TFake( FItems[aIndex]) := v;
end;

constructor TGRegularBinHeap.Create;
begin
  Create(TDefaults.Less);
end;

constructor TGRegularBinHeap.Create(c: TLess);
begin
  inherited Create;
  FLess := c;
end;

constructor TGRegularBinHeap.Create(aCapacity: SizeInt; c: TLess);
begin
  inherited Create(aCapacity);
  FLess := c;
end;

constructor TGRegularBinHeap.Create(const A: array of T; c: TLess);
begin
  inherited Create(A);
  FLess := c;
end;

constructor TGRegularBinHeap.Create(e: IEnumerable; c: TLess);
begin
  inherited Create(e);
  FLess := c;
end;

function TGRegularBinHeap.Comparator: TLess;
begin
  Result := FLess;
end;

{ TGDelegatedBinHeap }

procedure TGDelegatedBinHeap.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if ElemCount > 1 then
    begin
      HighIdx := Pred(ElemCount);
      for I := Pred(ElemCount shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if (Succ(NextIdx) <= HighIdx) and FLess(FItems[NextIdx], FItems[Succ(NextIdx)]) then
                Inc(NextIdx);
              if not FLess(T(v), FItems[NextIdx]) then
                break;
              TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGDelegatedBinHeap.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(ElemCount);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if(Succ(NextIdx) <= HighIdx) and FLess(FItems[NextIdx], FItems[Succ(NextIdx)]) then
            Inc(NextIdx);
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and FLess(FItems[NextIdx], T(v)) do
        begin
          TFake(FItems[CurrIdx]) := TFake(FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FItems[CurrIdx]) := v;
    end;
end;

procedure TGDelegatedBinHeap.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  ParentIdx := Pred(aIndex) shr 1;
  v := TFake(FItems[aIndex]);
  while(aIndex > 0) and FLess(FItems[ParentIdx], T(v)) do
    begin
      TFake(FItems[aIndex]) := TFake(FItems[ParentIdx]);
      aIndex := ParentIdx;
      ParentIdx := Pred(ParentIdx) shr 1;
    end;
  TFake( FItems[aIndex]) := v;
end;

constructor TGDelegatedBinHeap.Create;
begin
  Create(TDefaults.OnLess);
end;

constructor TGDelegatedBinHeap.Create(c: TComparator);
begin
  inherited Create;
  FLess := c;
end;

constructor TGDelegatedBinHeap.Create(aCapacity: SizeInt; c: TComparator);
begin
  inherited Create(aCapacity);
  FLess := c;
end;

constructor TGDelegatedBinHeap.Create(const A: array of T; c: TComparator);
begin
  inherited Create(A);
  FLess := c;
end;

constructor TGDelegatedBinHeap.Create(e: IEnumerable; c: TComparator);
begin
  inherited Create(e);
  FLess := c;
end;

function TGDelegatedBinHeap.Comparator: TOnLess;
begin
  Result := FLess;
end;

{ TGLiteBinHeap }

function TGLiteBinHeap.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

procedure TGLiteBinHeap.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if Count > 1 then
    begin
      HighIdx := Pred(Count);
      for I := Pred(Count shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(Items[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if (Succ(NextIdx) <= HighIdx) and TCmpRel.Less(Items[NextIdx], Items[Succ(NextIdx)])then
                Inc(NextIdx);
              if not TCmpRel.Less(T(v), Items[NextIdx]) then
                break;
              TFake(Items[CurrIdx]) := TFake(Items[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(Items[CurrIdx]) := v;
        end;
    end;
end;

procedure TGLiteBinHeap.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(Count);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(Items[0]);
      while NextIdx <= HighIdx do
        begin
          if (Succ(NextIdx) <= HighIdx) and TCmpRel.Less(Items[NextIdx], Items[Succ(NextIdx)])then
            Inc(NextIdx);
          TFake(Items[CurrIdx]) := TFake(Items[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and TCmpRel.Less(Items[NextIdx], T(v)) do
        begin
          TFake(Items[CurrIdx]) := TFake(Items[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(Items[CurrIdx]) := v;
    end;
end;

procedure TGLiteBinHeap.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  if aIndex > 0 then
    begin
      ParentIdx := Pred(aIndex) shr 1;
      v := TFake(FBuffer.FItems[aIndex]);
      while(aIndex > 0) and TCmpRel.Less(Items[ParentIdx], T(v)) do
        begin
          TFake(Items[aIndex]) := TFake(Items[ParentIdx]);
          aIndex := ParentIdx;
          ParentIdx := Pred(ParentIdx) shr 1;
        end;
      TFake(Items[aIndex]) := v;
    end;
end;

function TGLiteBinHeap.DequeueItem: T;
begin
  Result :=  FBuffer.FItems[0];
  Dec(FBuffer.FCount);
  if Count > 0 then
    begin
      Items[0] := Items[Count];
      Items[Count] := Default(T);
      SiftDown;
    end
  else
    FBuffer.FItems[0] := Default(T);
end;

class function TGLiteBinHeap.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

function TGLiteBinHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

function TGLiteBinHeap.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteBinHeap.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteBinHeap.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteBinHeap.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteBinHeap.Modified;
begin
  BuildHeap;
end;

function TGLiteBinHeap.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteBinHeap.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteBinHeap.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteBinHeap.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteBinHeap.Enqueue(const aValue: T);
begin
  FloatUp(FBuffer.PushLast(aValue));
end;

function TGLiteBinHeap.Dequeue: T;
begin
  FBuffer.CheckEmpty;
  Result := DequeueItem;
end;

function TGLiteBinHeap.TryDequeue(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := DequeueItem;
end;

function TGLiteBinHeap.Peek: T;
begin
  FBuffer.CheckEmpty;
  Result := FBuffer.FItems[0];
end;

function TGLiteBinHeap.TryPeek(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[0];
end;

{ TGLiteThreadBinHeap }

procedure TGLiteThreadBinHeap.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadBinHeap.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadBinHeap.Destroy;
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

procedure TGLiteThreadBinHeap.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadBinHeap.Enqueue(const aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadBinHeap.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadBinHeap.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadBinHeap.Lock: PQueue;
begin
  Result := @FQueue;
  DoLock;
end;

procedure TGLiteThreadBinHeap.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteComparableBinHeapMin }

function TGLiteComparableBinHeapMin.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

procedure TGLiteComparableBinHeapMin.BuildHeap;
var
  I, CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  if Count > 1 then
    begin
      HighIdx := Pred(Count);
      for I := Pred(Count shr 1) downto 0 do
        begin
          CurrIdx := I;
          NextIdx := Succ(I shl 1);
          v := TFake(FBuffer.FItems[CurrIdx]);
          while NextIdx <= HighIdx do
            begin
              if(Succ(NextIdx) <= HighIdx) and (FBuffer.FItems[Succ(NextIdx)] < FBuffer.FItems[NextIdx])then
                Inc(NextIdx);
              if not (FBuffer.FItems[NextIdx] < T(v)) then
                break;
              TFake(FBuffer.FItems[CurrIdx]) := TFake(FBuffer.FItems[NextIdx]);
              CurrIdx := NextIdx;
              NextIdx := Succ(NextIdx shl 1);
            end;
          TFake(FBuffer.FItems[CurrIdx]) := v;
        end;
    end;
end;

procedure TGLiteComparableBinHeapMin.SiftDown;
var
  CurrIdx, NextIdx, HighIdx: SizeInt;
  v: TFake;
begin
  HighIdx := Pred(Count);
  if HighIdx > 0 then
    begin
      CurrIdx := 0;
      NextIdx := 1;
      v := TFake(FBuffer.FItems[0]);
      while NextIdx <= HighIdx do
        begin
          if(Succ(NextIdx) <= HighIdx) and (FBuffer.FItems[Succ(NextIdx)] < FBuffer.FItems[NextIdx]) then
            Inc(NextIdx);
          TFake(FBuffer.FItems[CurrIdx]) := TFake(FBuffer.FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Succ(NextIdx shl 1);
        end;
      NextIdx := Pred(CurrIdx) shr 1;
      while (CurrIdx > 0) and (T(v) < FBuffer.FItems[NextIdx]) do
        begin
          TFake(FBuffer.FItems[CurrIdx]) := TFake(FBuffer.FItems[NextIdx]);
          CurrIdx := NextIdx;
          NextIdx := Pred(NextIdx) shr 1;
        end;
      TFake(FBuffer.FItems[CurrIdx]) := v;
    end;
end;

procedure TGLiteComparableBinHeapMin.FloatUp(aIndex: SizeInt);
var
  ParentIdx: SizeInt;
  v: TFake;
begin
  if aIndex > 0 then
    begin
      ParentIdx := Pred(aIndex) shr 1;
      v := TFake(FBuffer.FItems[aIndex]);
      while(aIndex > 0) and (T(v) < FBuffer.FItems[ParentIdx]) do
        begin
          TFake(FBuffer.FItems[aIndex]) := TFake(FBuffer.FItems[ParentIdx]);
          aIndex := ParentIdx;
          ParentIdx := Pred(ParentIdx) shr 1;
        end;
      TFake(FBuffer.FItems[aIndex]) := v;
    end;
end;

function TGLiteComparableBinHeapMin.DequeueItem: T;
begin
  Result :=  FBuffer.FItems[0];
  Dec(FBuffer.FCount);
  if Count > 0 then
    begin
      FBuffer.FItems[0] := FBuffer.FItems[Count];
      FBuffer.FItems[Count] := Default(T);
      SiftDown;
    end
  else
    FBuffer.FItems[0] := Default(T);
end;

class function TGLiteComparableBinHeapMin.DoCompare(const L, R: T): Boolean;
begin
  Result := L < R;
end;

function TGLiteComparableBinHeapMin.Comparator: TLess;
begin
  Result := @DoCompare;
end;

function TGLiteComparableBinHeapMin.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteComparableBinHeapMin.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteComparableBinHeapMin.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteComparableBinHeapMin.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteComparableBinHeapMin.Modified;
begin
  BuildHeap;
end;

function TGLiteComparableBinHeapMin.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteComparableBinHeapMin.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteComparableBinHeapMin.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteComparableBinHeapMin.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteComparableBinHeapMin.Enqueue(const aValue: T);
begin
  FloatUp(FBuffer.PushLast(aValue));
end;

function TGLiteComparableBinHeapMin.Dequeue: T;
begin
  FBuffer.CheckEmpty;
  Result := DequeueItem;
end;

function TGLiteComparableBinHeapMin.TryDequeue(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := DequeueItem;
end;

function TGLiteComparableBinHeapMin.Peek: T;
begin
  FBuffer.CheckEmpty;
  Result := FBuffer.FItems[0];
end;

function TGLiteComparableBinHeapMin.TryPeek(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[0];
end;

{ TGCustomPairingHeap.TNode }

procedure TGCustomPairingHeap.TNode.AddChild(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Prev := @Self;
      Sibling :=  aNode^.Sibling;
      if Sibling <> nil then
        Sibling^.Prev := @Self;
      aNode^.Sibling := Child;
      if aNode^.Sibling <> nil then
        aNode^.Sibling^.Prev := aNode;
      Child := aNode;
    end;
end;

procedure TGCustomPairingHeap.TNode.ClearLinks;
begin
  Sibling := nil;
  Child := nil;
  Prev := nil;
end;

function TGCustomPairingHeap.TNode.Successor: PNode;
begin
  Result := Sibling;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Sibling = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

function TGCustomPairingHeap.TNode.Predecessor: PNode;
begin
  Result := Child;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Child = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

{ TGCustomPairingHeap.TEnumerator }

function TGCustomPairingHeap.TEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

constructor TGCustomPairingHeap.TEnumerator.Create(aHeap: TCustomPairingHeap);
begin
  inherited Create(aHeap);
  FLeftmost := aHeap.FindLeftmost;
end;

function TGCustomPairingHeap.TEnumerator.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Successor
  else
    if not FInCycle then
      begin
        NextNode := FLeftmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGCustomPairingHeap.TEnumerator.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGCustomPairingHeap.TReverseEnum }

function TGCustomPairingHeap.TReverseEnum.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

constructor TGCustomPairingHeap.TReverseEnum.Create(aHeap: TCustomPairingHeap);
begin
  inherited Create(aHeap);
  FRightmost := aHeap.FindRightmost;
end;

function TGCustomPairingHeap.TReverseEnum.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Predecessor
  else
    if not FInCycle then
      begin
        NextNode := FRightmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGCustomPairingHeap.TReverseEnum.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGCustomPairingHeap }

procedure TGCustomPairingHeap.CheckEmpty;
begin
  if FCount = 0 then
    AccessEmptyError;
end;

function TGCustomPairingHeap.GetCount: SizeInt;
begin
  Result := FCount;
end;

function TGCustomPairingHeap.GetCapacity: SizeInt;
begin
  Result := FCount;
end;

procedure TGCustomPairingHeap.CopyItems(aBuffer: PItem);
var
  Node: PNode;
  I: SizeInt = 0;
begin
  Node := FindLeftmost;
  while Node <> nil do
    begin
      aBuffer[I] := Node^.Data;
      Inc(I);
      Node := Node^.Successor;
    end;
end;

function TGCustomPairingHeap.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGCustomPairingHeap.DoClear;
begin
  ClearTree;
end;

procedure TGCustomPairingHeap.DoTrimToFit;
begin
end;

procedure TGCustomPairingHeap.DoEnsureCapacity(aValue: SizeInt);
begin
  Assert(aValue = aValue);
end;

function TGCustomPairingHeap.NewNode(const aValue: T): PNode;
begin
  Result := GetMem(SizeOf(TNode));
  FillChar(Result^, SizeOf(TNode), 0);
  Result^.Data := aValue;
  Inc(FCount);
end;

procedure TGCustomPairingHeap.DisposeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Data := Default(T);
      FreeMem(aNode);
      Dec(FCount);
    end;
end;

procedure TGCustomPairingHeap.RemoveNodeWithChilds(aNode: PNode);
var
  OldPrev, OldNode, CurrNode: PNode;
  FromSibling: Boolean = False;
begin
  if aNode <> nil then
    begin
      CurrNode := aNode;
      repeat  //postorder traverse
        while FromSibling do
          begin
            OldPrev := CurrNode^.Prev;
            OldNode := CurrNode;
            /////////////////////////////////
            DisposeNode(CurrNode);
            ////////////////////////////////
            if CurrNode = aNode then
              exit;
            CurrNode := OldPrev;
            FromSibling := CurrNode^.Sibling = OldNode;
            if not FromSibling and (CurrNode^.Sibling <> nil) then
              CurrNode := CurrNode^.Sibling
            else
              FromSibling := True;
          end;
        while CurrNode^.Child <> nil do
          CurrNode := CurrNode^.Child;
        if CurrNode^.Sibling <> nil then
          CurrNode := CurrNode^.Sibling
        else
          FromSibling := True;
      until False;
    end;
end;

procedure TGCustomPairingHeap.ClearTree;
begin
  RemoveNodeWithChilds(FRoot);
  FRoot := nil;
end;

function TGCustomPairingHeap.FindLeftmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child;
end;

function TGCustomPairingHeap.FindRightmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling;
end;

function TGCustomPairingHeap.EnqueueArray(const a: array of T): SizeInt;
var
  v: T;
begin
  Result := System.Length(a);
  for v in a do
    DoEnqueue(v);
end;

function TGCustomPairingHeap.EnqueueContainer(c: TSpecContainer): SizeInt;
var
  v: T;
begin
  if c <> Self then
    begin
      Result := c.Count;
      for v in c do
        DoEnqueue(v);
    end
  else
    Result := EnqueueArray(c.ToArray);
end;

function TGCustomPairingHeap.EnqueueEnum(e: IEnumerable): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        DoEnqueue(Current);
    finally
      Free;
    end;
  Result := Count - Result;
end;

class procedure TGCustomPairingHeap.CutNode(aNode: PNode);
begin
  if aNode^.Sibling <> nil then
    aNode^.Sibling^.Prev := aNode^.Prev;
  if aNode^.Prev^.Child = aNode then
    aNode^.Prev^.Child := aNode^.Sibling
  else
    aNode^.Prev^.Sibling := aNode^.Sibling;
  aNode^.Sibling := nil;
end;

class function TGCustomPairingHeap.Ptr2Handle(aNode: PNode): THandle;
var
  h: THandle absolute aNode;
begin
  Result := h;
end;

class function TGCustomPairingHeap.Handle2Ptr(h: THandle): PNode;
var
  p: PNode absolute h;
begin
  Result := p;
end;

destructor TGCustomPairingHeap.Destroy;
begin
  DoClear;
  inherited;
end;

function TGCustomPairingHeap.Reverse: IEnumerable;
begin
  Result := TReverseEnum.Create(Self);
end;

procedure TGCustomPairingHeap.Enqueue(const aValue: T);
begin
  CheckInIteration;
  DoEnqueue(aValue);
end;

function TGCustomPairingHeap.EnqueueAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := EnqueueArray(a);
end;

function TGCustomPairingHeap.EnqueueAll(e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  if not InIteration then
    begin
      o := e._GetRef;
      if o is TSpecContainer then
        Result := EnqueueContainer(TSpecContainer(o))
      else
        Result := EnqueueEnum(e);
    end
  else
    begin
      Result := 0;
      e.Any;
      UpdateLockError;
    end;
end;

function TGCustomPairingHeap.Dequeue: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := DoDequeue;
end;

function TGCustomPairingHeap.TryDequeue(out aValue: T): Boolean;
begin
  Result := not InIteration and (FCount > 0);
  if Result then
    aValue := DoDequeue;
end;

function TGCustomPairingHeap.Peek: T;
begin
  CheckEmpty;
  Result := FRoot^.Data;
end;

function TGCustomPairingHeap.TryPeek(out aValue: T): Boolean;
begin
  Result := FCount > 0;
  if Result then
    aValue := FRoot^.Data;
end;

function TGCustomPairingHeap.Insert(const aValue: T): THandle;
begin
  CheckInIteration;
  Result := Ptr2Handle(DoEnqueue(aValue));
end;

function TGCustomPairingHeap.PeekHandle: THandle;
begin
  CheckEmpty;
  Result := Ptr2Handle(FRoot);
end;

function TGCustomPairingHeap.TryPeekHandle(out aHandle: THandle): Boolean;
begin
  Result := FCount > 0;
  if Result then
    aHandle := Ptr2Handle(FRoot);
end;

function TGCustomPairingHeap.ValueOf(aHandle: THandle): T;
begin
  Result := Handle2Ptr(aHandle)^.Data;
end;

procedure TGCustomPairingHeap.Update(aHandle: THandle; const aValue: T);
begin
  CheckInIteration;
  CheckEmpty;
  DoUpdate(Handle2Ptr(aHandle), aValue);
end;

function TGCustomPairingHeap.Remove(aHandle: THandle): T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := DoRemove(Handle2Ptr(aHandle));
end;

function TGCustomPairingHeap.Merge(aQueue: IPriorityQueue): SizeInt;
var
  o: TObject;
begin
  o := aQueue._GetRef;
  if o <> Self then
    begin
      CheckInIteration;
      TSpecContainer(o).CheckInIteration;
      if o is TCustomPairingHeap then
        Result := DoMergeHeap(TCustomPairingHeap(o))
      else
        begin
          Result := EnqueueAll(aQueue);
          aQueue.Clear;
        end;
    end
  else
    Result := 0;
end;

{ TGBasePairingHeap }

procedure TGBasePairingHeap.RootMerge(aNode: PNode);
begin
  FRoot := DoMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

procedure TGBasePairingHeap.DoExtract(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGBasePairingHeap.DoEnqueue(const aValue: T): PNode;
begin
  Result := NewNode(aValue);
  RootMerge(Result);
end;

procedure TGBasePairingHeap.DoUpdate(aNode: PNode; const aValue: T);
begin
  if TCmpRel.Less(aNode^.Data, aValue) then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if TCmpRel.Less(aValue, aNode^.Data) then
      begin
        aNode^.Data := aValue;
        DoExtract(aNode);
        RootMerge(aNode);
      end;
end;

function TGBasePairingHeap.DoRemove(aNode: PNode): T;
begin
  DoExtract(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

function TGBasePairingHeap.DoDequeue: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

function TGBasePairingHeap.DoMergeHeap(ph: TCustomPairingHeap): SizeInt;
begin
  Result := ph.Count;
  if Result > 0 then
    begin
      if ph is TGBasePairingHeap then
        begin
          RootMerge(ph.FRoot);
          FCount += Result;
          ph.FCount := 0;
          ph.FRoot := nil;
        end
      else
        begin
          EnqueueAll(ph);
          ph.Clear;
        end;
    end;
end;

class function TGBasePairingHeap.DoMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    if R <> nil then
      if TCmpRel.Less(L^.Data, R^.Data) then
        begin
          R^.AddChild(L);
          Result := R;
        end
      else
        begin
          L^.AddChild(R);
          Result := L;
        end
    else
      Result := L
  else
    Result := R;
end;

class function TGBasePairingHeap.TwoPassMerge(aNode: PNode): PNode;
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := DoMerge(Result, DoMerge(CurrNode, NextNode));
    end;
  Result := DoMerge(Result, aNode);
end;

class function TGBasePairingHeap.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

class function TGBasePairingHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

constructor TGBasePairingHeap.Create(const A: array of T);
begin
  EnqueueAll(A);
end;

constructor TGBasePairingHeap.Create(e: IEnumerable);
begin
  EnqueueAll(e);
end;

{ TGComparablePairHeap }

class function TGComparablePairHeap.DoCompare(const L, R: T): Boolean;
begin
  Result :=  L < R;
end;

class function TGComparablePairHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

{ TGComparablePairHeapMax }

procedure TGComparablePairHeapMax.RootMerge(aNode: PNode);
begin
  FRoot := DoMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

procedure TGComparablePairHeapMax.DoExtract(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGComparablePairHeapMax.DoEnqueue(const aValue: T): PNode;
begin
  Result := NewNode(aValue);
  RootMerge(Result);
end;

procedure TGComparablePairHeapMax.DoUpdate(aNode: PNode; const aValue: T);
begin
  if aNode^.Data < aValue then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if aValue < aNode^.Data then
      begin
        aNode^.Data := aValue;
        DoExtract(aNode);
        RootMerge(aNode);
      end;
end;

function TGComparablePairHeapMax.DoRemove(aNode: PNode): T;
begin
  DoExtract(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

function TGComparablePairHeapMax.DoDequeue: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

function TGComparablePairHeapMax.DoMergeHeap(ph: TCustomPairingHeap): SizeInt;
begin
  Result := ph.Count;
  if Result > 0 then
    begin
      if ph is TGComparablePairHeapMax then
        begin
          RootMerge(ph.FRoot);
          FCount += Result;
          ph.FCount := 0;
          ph.FRoot := nil;
        end
      else
        begin
          EnqueueAll(ph);
          ph.Clear;
        end;
    end;
end;

class function TGComparablePairHeapMax.DoMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    if R <> nil then
      if L^.Data < R^.Data then
        begin
          R^.AddChild(L);
          Result := R;
        end
      else
        begin
          L^.AddChild(R);
          Result := L;
        end
    else
      Result := L
  else
    Result := R;
end;

class function TGComparablePairHeapMax.TwoPassMerge(aNode: PNode): PNode;
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := DoMerge(Result, DoMerge(CurrNode, NextNode));
    end;
  Result := DoMerge(Result, aNode);
end;

constructor TGComparablePairHeapMax.Create(const A: array of T);
begin
  EnqueueAll(A);
end;

constructor TGComparablePairHeapMax.Create(e: IEnumerable);
begin
  EnqueueAll(e);
end;

{ TGComparablePairHeapMin }

procedure TGComparablePairHeapMin.RootMerge(aNode: PNode);
begin
  FRoot := DoMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

procedure TGComparablePairHeapMin.DoExtract(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGComparablePairHeapMin.DoEnqueue(const aValue: T): PNode;
begin
  Result := NewNode(aValue);
  RootMerge(Result);
end;

procedure TGComparablePairHeapMin.DoUpdate(aNode: PNode; const aValue: T);
begin
  if aValue < aNode^.Data then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if aNode^.Data < aValue then
      begin
        aNode^.Data := aValue;
        DoExtract(aNode);
        RootMerge(aNode);
      end;
end;

function TGComparablePairHeapMin.DoRemove(aNode: PNode): T;
begin
  DoExtract(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

function TGComparablePairHeapMin.DoDequeue: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

function TGComparablePairHeapMin.DoMergeHeap(ph: TCustomPairingHeap): SizeInt;
begin
  Result := ph.Count;
  if Result > 0 then
    begin
      if ph is TGComparablePairHeapMin then
        begin
          RootMerge(ph.FRoot);
          FCount += Result;
          ph.FCount := 0;
          ph.FRoot := nil;
        end
      else
        begin
          EnqueueAll(ph);
          ph.Clear;
        end;
    end;
end;

class function TGComparablePairHeapMin.DoMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    if R <> nil then
      if R^.Data < L^.Data then
        begin
          R^.AddChild(L);
          Result := R;
        end
      else
        begin
          L^.AddChild(R);
          Result := L;
        end
    else
      Result := L
  else
    Result := R;
end;

class function TGComparablePairHeapMin.TwoPassMerge(aNode: PNode): PNode; // non recursive
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := DoMerge(Result, DoMerge(CurrNode, NextNode));
    end;
  Result := DoMerge(Result, aNode);
end;

constructor TGComparablePairHeapMin.Create(const A: array of T);
begin
  EnqueueAll(A);
end;

constructor TGComparablePairHeapMin.Create(e: IEnumerable);
begin
  EnqueueAll(e);
end;

{ TGRegularPairHeap }

function TGRegularPairHeap.DoMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    begin
      if R <> nil then
        begin
          if not FLess(L^.Data, R^.Data) then
            begin
              L^.AddChild(R);
              Result := L;
            end
          else
            begin
              R^.AddChild(L);
              Result := R;
            end;
        end
      else
        Result := L;
    end
  else
    Result := R;
end;

procedure TGRegularPairHeap.RootMerge(aNode: PNode);
begin
  FRoot := DoMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

function TGRegularPairHeap.TwoPassMerge(aNode: PNode): PNode; // non recursive
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := DoMerge(Result, DoMerge(CurrNode, NextNode));
    end;
  if aNode <> nil then
    Result := DoMerge(Result, aNode);
end;

procedure TGRegularPairHeap.DoExtract(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGRegularPairHeap.DoEnqueue(const aValue: T): PNode;
begin
  Result := NewNode(aValue);
  RootMerge(Result);
end;

procedure TGRegularPairHeap.DoUpdate(aNode: PNode; const aValue: T);
begin
  if FLess(aNode^.Data, aValue) then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if FLess(aValue, aNode^.Data) then
      begin
        aNode^.Data := aValue;
        DoExtract(aNode);
        RootMerge(aNode);
      end;
end;

function TGRegularPairHeap.DoRemove(aNode: PNode): T;
begin
  DoExtract(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

function TGRegularPairHeap.DoDequeue: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

function TGRegularPairHeap.DoMergeHeap(ph: TCustomPairingHeap): SizeInt;
begin
  Result := ph.Count;
  if Result > 0 then
    begin
      if ph is TGRegularPairHeap then
        begin
          RootMerge(ph.FRoot);
          FCount += Result;
          ph.FCount := 0;
          ph.FRoot := nil;
        end
      else
        begin
          EnqueueAll(ph);
          ph.Clear;
        end;
    end;
end;

constructor TGRegularPairHeap.Create;
begin
  Create(TDefaults.Less);
end;

constructor TGRegularPairHeap.Create(c: TLess);
begin
  FLess := c;
end;

constructor TGRegularPairHeap.Create(const A: array of T; c: TLess);
begin
  Create(c);
  EnqueueAll(A);
end;

constructor TGRegularPairHeap.Create(e: IEnumerable; c: TLess);
begin
  Create(c);
  EnqueueAll(e);
end;

function TGRegularPairHeap.Comparator: TLess;
begin
  Result := FLess;
end;

{ TGDelegatedPairHeap }

function TGDelegatedPairHeap.DoMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    begin
      if R <> nil then
        begin
          if not FLess(L^.Data, R^.Data) then
            begin
              L^.AddChild(R);
              Result := L;
            end
          else
            begin
              R^.AddChild(L);
              Result := R;
            end;
        end
      else
        Result := L;
    end
  else
    Result := R;
end;

procedure TGDelegatedPairHeap.RootMerge(aNode: PNode);
begin
  FRoot := DoMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

function TGDelegatedPairHeap.TwoPassMerge(aNode: PNode): PNode; // non recursive
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := DoMerge(Result, DoMerge(CurrNode, NextNode));
    end;
  if aNode <> nil then
    Result := DoMerge(Result, aNode);
end;

procedure TGDelegatedPairHeap.DoExtract(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGDelegatedPairHeap.DoEnqueue(const aValue: T): PNode;
begin
  Result := NewNode(aValue);
  RootMerge(Result);
end;

procedure TGDelegatedPairHeap.DoUpdate(aNode: PNode; const aValue: T);
begin
  if FLess(aNode^.Data, aValue) then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if FLess(aValue, aNode^.Data) then
      begin
        aNode^.Data := aValue;
        DoExtract(aNode);
        RootMerge(aNode);
      end;
end;

function TGDelegatedPairHeap.DoRemove(aNode: PNode): T;
begin
  DoExtract(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

function TGDelegatedPairHeap.DoDequeue: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

function TGDelegatedPairHeap.DoMergeHeap(ph: TCustomPairingHeap): SizeInt;
begin
  Result := ph.Count;
  if Result > 0 then
    begin
      if ph is TGDelegatedPairHeap then
        begin
          RootMerge(ph.FRoot);
          FCount += Result;
          ph.FCount := 0;
          ph.FRoot := nil;
        end
      else
        begin
          EnqueueAll(ph);
          ph.Clear;
        end;
    end;
end;

constructor TGDelegatedPairHeap.Create;
begin
  Create(TDefaults.OnLess);
end;

constructor TGDelegatedPairHeap.Create(c: TOnLess);
begin
  FLess := c;
end;

constructor TGDelegatedPairHeap.Create(const A: array of T; c: TOnLess);
begin
  Create(c);
  EnqueueAll(A);
end;

constructor TGDelegatedPairHeap.Create(e: IEnumerable; c: TOnLess);
begin
  Create(c);
  EnqueueAll(e);
end;

function TGDelegatedPairHeap.Comparator: TOnLess;
begin
  Result := FLess;
end;

{ TGLitePairingHeap.TNode }

procedure TGLitePairingHeap.TNode.AddChild(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Prev := @Self;
      Sibling :=  aNode^.Sibling;
      if Sibling <> nil then
        Sibling^.Prev := @Self;
      aNode^.Sibling := Child;
      if aNode^.Sibling <> nil then
        aNode^.Sibling^.Prev := aNode;
      Child := aNode;
    end;
end;

procedure TGLitePairingHeap.TNode.ClearLinks;
begin
  Sibling := nil;
  Child := nil;
  Prev := nil;
end;

function TGLitePairingHeap.TNode.Successor: PNode;
begin
  Result := Sibling;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Sibling = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

function TGLitePairingHeap.TNode.Predecessor: PNode;
begin
  Result := Child;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Child = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

{ TGLitePairingHeap.TEnumerator }

function TGLitePairingHeap.TEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

function TGLitePairingHeap.TEnumerator.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Successor
  else
    if not FInCycle then
      begin
        NextNode := FLeftmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLitePairingHeap.TEnumerator.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGLitePairingHeap.TReverseEnumerator }

function TGLitePairingHeap.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

function TGLitePairingHeap.TReverseEnumerator.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Predecessor
  else
    if not FInCycle then
      begin
        NextNode := FRightmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLitePairingHeap.TReverseEnumerator.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGLitePairingHeap.TReverse }

function TGLitePairingHeap.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result := FHeap^.GetReverseEnumerator;
end;

{ TGLitePairingHeap }

function TGLitePairingHeap.GetReverseEnumerator: TReverseEnumerator;
begin
  Result.FCurrNode := nil;
  Result.FRightmost := FindRightmost;
  Result.FInCycle := False;
end;

function TGLitePairingHeap.FindLeftmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child;
end;

function TGLitePairingHeap.FindRightmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling;
end;

procedure TGLitePairingHeap.RemoveNodeWithChilds(aNode: PNode);
var
  OldPrev, OldNode, CurrNode: PNode;
  FromSibling: Boolean = False;
begin
  if aNode <> nil then
    begin
      CurrNode := aNode;
      repeat  //postorder traverse
        while FromSibling do
          begin
            OldPrev := CurrNode^.Prev;
            OldNode := CurrNode;
            /////////////////////////////////
            DisposeNode(CurrNode);
            ////////////////////////////////
            if CurrNode = aNode then
              exit;
            CurrNode := OldPrev;
            FromSibling := CurrNode^.Sibling = OldNode;
            if not FromSibling and (CurrNode^.Sibling <> nil) then
              CurrNode := CurrNode^.Sibling
            else
              FromSibling := True;
          end;
        while CurrNode^.Child <> nil do
          CurrNode := CurrNode^.Child;
        if CurrNode^.Sibling <> nil then
          CurrNode := CurrNode^.Sibling
        else
          FromSibling := True;
      until False;
    end;
end;

procedure TGLitePairingHeap.ClearTree;
begin
  RemoveNodeWithChilds(FRoot);
  FRoot := nil;
end;

function TGLitePairingHeap.NewNode(const aValue: T): PNode;
begin
  Result := GetMem(SizeOf(TNode));
  FillChar(Result^, SizeOf(TNode), 0);
  Result^.Data := aValue;
  Inc(FCount);
end;

procedure TGLitePairingHeap.DisposeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Data := Default(T);
      FreeMem(aNode);
      Dec(FCount);
    end;
end;

procedure TGLitePairingHeap.RootMerge(aNode: PNode);
begin
  FRoot := NodeMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

function TGLitePairingHeap.DequeueItem: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

procedure TGLitePairingHeap.UpdateNode(aNode: PNode; const aValue: T);
begin
  if TCmpRel.Less(aNode^.Data, aValue) then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if TCmpRel.Less(aValue, aNode^.Data) then
      begin
        aNode^.Data := aValue;
        ExtractNode(aNode);
        RootMerge(aNode);
      end;
end;

procedure TGLitePairingHeap.ExtractNode(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGLitePairingHeap.RemoveNode(aNode: PNode): T;
begin
  ExtractNode(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

procedure TGLitePairingHeap.CheckEmpty;
begin
  if Count = 0 then
    AccessEmptyError;
end;

procedure TGLitePairingHeap.AccessEmptyError;
begin
  raise ELGAccessEmpty.Create(SECantAccessEmpty);
end;

class operator TGLitePairingHeap.Initialize(var h: TGLitePairingHeap);
begin
  h.FRoot := nil;
  h.FCount := 0;
end;

class operator TGLitePairingHeap.Finalize(var h: TGLitePairingHeap);
begin
  h.ClearTree;
end;

class operator TGLitePairingHeap.Copy(constref aSrc: TGLitePairingHeap; var aDst: TGLitePairingHeap);
var
  v: T;
begin
  if @aDst = @aSrc then
    exit;
  aDst.ClearTree;
  for v in aSrc do
    aDst.Enqueue(v);
end;

class operator TGLitePairingHeap.AddRef(var h: TGLitePairingHeap);
var
  e: TEnumerator;
begin
  e := h.GetEnumerator;
  h.FRoot := nil;
  h.FCount := 0;
  while e.MoveNext do
    h.Enqueue(e.Current);
end;

class function TGLitePairingHeap.NodeMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    if R <> nil then
      if not TCmpRel.Less(L^.Data, R^.Data) then
        begin
          L^.AddChild(R);
          Result := L;
        end
      else
        begin
          R^.AddChild(L);
          Result := R;
        end
    else
      Result := L
  else
    Result := R;
end;

class function TGLitePairingHeap.TwoPassMerge(aNode: PNode): PNode;
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      CurrNode := aNode;
      NextNode := aNode^.Sibling;
      aNode := NextNode^.Sibling;
      CurrNode^.Sibling := nil;
      NextNode^.Sibling := nil;
      Result := NodeMerge(Result, NodeMerge(CurrNode, NextNode));
    end;
  Result := NodeMerge(Result, aNode);
end;

class procedure TGLitePairingHeap.CutNode(aNode: PNode);
begin
  if aNode^.Sibling <> nil then
    aNode^.Sibling^.Prev := aNode^.Prev;
  if aNode^.Prev^.Child = aNode then
    aNode^.Prev^.Child := aNode^.Sibling
  else
    aNode^.Prev^.Sibling := aNode^.Sibling;
  aNode^.Sibling := nil;
end;

class function TGLitePairingHeap.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

class function TGLitePairingHeap.Ptr2Handle(aNode: PNode): THandle;
var
  h: THandle absolute aNode;
begin
  Result := h;
end;

class function TGLitePairingHeap.Handle2Ptr(h: THandle): PNode;
var
  p: PNode absolute h;
begin
  Result := p;
end;

function TGLitePairingHeap.Comparator: TLess;
begin
  Result := @DoCompare;
end;

function TGLitePairingHeap.GetEnumerator: TEnumerator;
begin
  Result.FCurrNode := nil;
  Result.FLeftmost := FindLeftmost;
  Result.FInCycle := False;
end;

function TGLitePairingHeap.Reverse: TReverse;
begin
  Result.FHeap := @Self;
end;

function TGLitePairingHeap.ToArray: TArray;
var
  I: SizeInt = 0;
  v: T;
begin
  System.SetLength(Result, Count);
  for v in Self do
    begin
      Result[I] := v;
      Inc(I);
    end;
end;

procedure TGLitePairingHeap.Clear;
begin
  ClearTree;
end;

function TGLitePairingHeap.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLitePairingHeap.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLitePairingHeap.Enqueue(const aValue: T);
begin
  RootMerge(NewNode(aValue));
end;

function TGLitePairingHeap.Dequeue: T;
begin
  CheckEmpty;
  Result := DequeueItem;
end;

function TGLitePairingHeap.TryDequeue(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := DequeueItem;
end;

function TGLitePairingHeap.Peek: T;
begin
  CheckEmpty;
  Result := FRoot^.Data;
end;

function TGLitePairingHeap.TryPeek(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FRoot^.Data;
end;

function TGLitePairingHeap.Insert(const aValue: T): THandle;
var
  p: PNode;
begin
  p := NewNode(aValue);
  RootMerge(p);
  Result := Ptr2Handle(p);
end;

function TGLitePairingHeap.PeekHandle: THandle;
begin
  CheckEmpty;
  Result := Ptr2Handle(FRoot);
end;

function TGLitePairingHeap.TryPeekHandle(out aValue: THandle): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := Ptr2Handle(FRoot);
end;

function TGLitePairingHeap.ValueOf(aHandle: THandle): T;
begin
  Result := Handle2Ptr(aHandle)^.Data;
end;

procedure TGLitePairingHeap.Update(aHandle: THandle; const aValue: T);
begin
  CheckEmpty;
  UpdateNode(Handle2Ptr(aHandle), aValue);
end;

function TGLitePairingHeap.Remove(aHandle: THandle): T;
begin
  CheckEmpty;
  Result := RemoveNode(Handle2Ptr(aHandle));
end;

function TGLitePairingHeap.Merge(var aHeap: TGLitePairingHeap): SizeInt;
begin
  if @Self = @aHeap then
    exit(0);
  Result := aHeap.Count;
  if Result > 0 then
    begin
      RootMerge(aHeap.FRoot);
      FCount += Result;
      aHeap.FCount := 0;
      aHeap.FRoot := nil;
    end;
end;

{ TGLiteComparablePairHeapMin.TNode }

procedure TGLiteComparablePairHeapMin.TNode.AddChild(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Prev := @Self;
      Sibling :=  aNode^.Sibling;
      if Sibling <> nil then
        Sibling^.Prev := @Self;
      aNode^.Sibling := Child;
      if Child <> nil then
        Child^.Prev := aNode;
      Child := aNode;
    end;
end;

procedure TGLiteComparablePairHeapMin.TNode.ClearLinks;
begin
  Sibling := nil;
  Child := nil;
  Prev := nil;
end;

function TGLiteComparablePairHeapMin.TNode.Successor: PNode;
begin
  Result := Sibling;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Sibling = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

function TGLiteComparablePairHeapMin.TNode.Predecessor: PNode;
begin
  Result := Child;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling
  else
    begin
      Result := @Self;
      while (Result^.Prev <> nil) and (Result^.Prev^.Child = Result) do
        Result := Result^.Prev;
      Result := Result^.Prev;
    end;
end;

{ TGLiteComparablePairHeapMin.TEnumerator }

function TGLiteComparablePairHeapMin.TEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

function TGLiteComparablePairHeapMin.TEnumerator.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Successor
  else
    if not FInCycle then
      begin
        NextNode := FLeftmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLiteComparablePairHeapMin.TEnumerator.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGLiteComparablePairHeapMin.TReverseEnumerator }

function TGLiteComparablePairHeapMin.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

function TGLiteComparablePairHeapMin.TReverseEnumerator.MoveNext: Boolean;
var
  NextNode: PNode = nil;
begin
  if FCurrNode <> nil then
    NextNode := FCurrNode^.Predecessor
  else
    if not FInCycle then
      begin
        NextNode := FRightmost;
        FInCycle := True;
      end;
  Result := NextNode <> nil;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLiteComparablePairHeapMin.TReverseEnumerator.Reset;
begin
  FCurrNode := nil;
  FInCycle := False;
end;

{ TGLiteComparablePairHeapMin.TReverse }

function TGLiteComparablePairHeapMin.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result := FHeap^.GetReverseEnumerator;
end;

{ TGLiteComparablePairHeapMin }

function TGLiteComparablePairHeapMin.GetReverseEnumerator: TReverseEnumerator;
begin
  Result.FCurrNode := nil;
  Result.FRightmost := FindRightmost;
  Result.FInCycle := False;
end;

function TGLiteComparablePairHeapMin.FindLeftmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Child <> nil do
      Result := Result^.Child;
end;

function TGLiteComparablePairHeapMin.FindRightmost: PNode;
begin
  Result := FRoot;
  if Result <> nil then
    while Result^.Sibling <> nil do
      Result := Result^.Sibling;
end;

procedure TGLiteComparablePairHeapMin.RemoveNodeWithChilds(aNode: PNode);
var
  OldPrev, OldNode, CurrNode: PNode;
  FromSibling: Boolean = False;
begin
  if aNode <> nil then
    begin
      CurrNode := aNode;
      repeat  //postorder traverse
        while FromSibling do
          begin
            OldPrev := CurrNode^.Prev;
            OldNode := CurrNode;
            /////////////////////////////////
            DisposeNode(CurrNode);
            ////////////////////////////////
            if CurrNode = aNode then
              exit;
            CurrNode := OldPrev;
            FromSibling := CurrNode^.Sibling = OldNode;
            if not FromSibling and (CurrNode^.Sibling <> nil) then
              CurrNode := CurrNode^.Sibling
            else
              FromSibling := True;
          end;
        while CurrNode^.Child <> nil do
          CurrNode := CurrNode^.Child;
        if CurrNode^.Sibling <> nil then
          CurrNode := CurrNode^.Sibling
        else
          FromSibling := True;
      until False;
    end;
end;

procedure TGLiteComparablePairHeapMin.ClearTree;
begin
  RemoveNodeWithChilds(FRoot);
  FRoot := nil;
end;

function TGLiteComparablePairHeapMin.NewNode(const aValue: T): PNode;
begin
  Result := GetMem(SizeOf(TNode));
  FillChar(Result^, SizeOf(TNode), 0);
  Result^.Data := aValue;
  Inc(FCount);
end;

procedure TGLiteComparablePairHeapMin.DisposeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Data := Default(T);
      FreeMem(aNode);
      Dec(FCount);
    end;
end;

procedure TGLiteComparablePairHeapMin.RootMerge(aNode: PNode);
begin
  FRoot := NodeMerge(FRoot, aNode);
  if FRoot <> nil then
    FRoot^.Prev := nil;
end;

function TGLiteComparablePairHeapMin.DequeueItem: T;
var
  OldRoot: PNode;
begin
  OldRoot := FRoot;
  Result := FRoot^.Data;
  FRoot := TwoPassMerge(FRoot^.Child);
  if FRoot <> nil then
    FRoot^.Prev := nil;
  DisposeNode(OldRoot);
end;

procedure TGLiteComparablePairHeapMin.UpdateNode(aNode: PNode; const aValue: T);
begin
  if aValue < aNode^.Data then
    begin
      aNode^.Data := aValue;
      if aNode <> FRoot then
        begin
          CutNode(aNode);
          RootMerge(aNode);
        end;
    end
  else
    if aNode^.Data < aValue then
      begin
        aNode^.Data := aValue;
        ExtractNode(aNode);
        RootMerge(aNode);
      end;
end;

procedure TGLiteComparablePairHeapMin.ExtractNode(aNode: PNode);
begin
  if aNode <> FRoot then
    begin
      CutNode(aNode);
      RootMerge(TwoPassMerge(aNode^.Child));
    end
  else
    begin
      FRoot := TwoPassMerge(FRoot^.Child);
      if FRoot <> nil then
        FRoot^.Prev := nil;
    end;
  aNode^.ClearLinks;
end;

function TGLiteComparablePairHeapMin.RemoveNode(aNode: PNode): T;
begin
  ExtractNode(aNode);
  Result := aNode^.Data;
  DisposeNode(aNode);
end;

procedure TGLiteComparablePairHeapMin.CheckEmpty;
begin
  if Count = 0 then
    AccessEmptyError;
end;

procedure TGLiteComparablePairHeapMin.AccessEmptyError;
begin
  raise ELGAccessEmpty.Create(SECantAccessEmpty);
end;

class operator TGLiteComparablePairHeapMin.Initialize(var h: TGLiteComparablePairHeapMin);
begin
  h.FRoot := nil;
  h.FCount := 0;
end;

class operator TGLiteComparablePairHeapMin.Finalize(var h: TGLiteComparablePairHeapMin);
begin
  h.ClearTree;
end;

class operator TGLiteComparablePairHeapMin.Copy(constref aSrc: TGLiteComparablePairHeapMin;
  var aDst: TGLiteComparablePairHeapMin);
var
  v: T;
begin
  if @aDst = @aSrc then
    exit;
  aDst.ClearTree;
  for v in aSrc do
    aDst.Enqueue(v);
end;

class operator TGLiteComparablePairHeapMin.AddRef(var h: TGLiteComparablePairHeapMin);
var
  e: TEnumerator;
begin
  e := h.GetEnumerator;
  h.FRoot := nil;
  h.FCount := 0;
  while e.MoveNext do
    h.Enqueue(e.Current);
end;

class function TGLiteComparablePairHeapMin.NodeMerge(L, R: PNode): PNode;
begin
  if L <> nil then
    if R <> nil then
      if R^.Data < L^.Data  then
        begin
          R^.AddChild(L);
          Result := R;
        end
      else
        begin
          L^.AddChild(R);
          Result := L;
        end
    else
      Result := L
  else
    Result := R;
end;

class function TGLiteComparablePairHeapMin.TwoPassMerge(aNode: PNode): PNode;
var
  CurrNode, NextNode: PNode;
begin
  Result := nil;
  while (aNode <> nil) and (aNode^.Sibling <> nil) do
    begin
      NextNode := aNode^.Sibling;
      CurrNode := aNode;
      aNode := NextNode^.Sibling;
      NextNode^.Sibling := nil;
      CurrNode^.Sibling := nil;
      Result := NodeMerge(Result, NodeMerge(CurrNode, NextNode));
    end;
  Result := NodeMerge(Result, aNode);
end;

class procedure TGLiteComparablePairHeapMin.CutNode(aNode: PNode);
begin
  if aNode^.Sibling <> nil then
    aNode^.Sibling^.Prev := aNode^.Prev;
  if aNode^.Prev^.Child = aNode then
    aNode^.Prev^.Child := aNode^.Sibling
  else
    aNode^.Prev^.Sibling := aNode^.Sibling;
  aNode^.Sibling := nil;
end;

class function TGLiteComparablePairHeapMin.DoCompare(const L, R: T): Boolean;
begin
  Result := L < R;
end;

class function TGLiteComparablePairHeapMin.Ptr2Handle(aNode: PNode): THandle;
var
  h: THandle absolute aNode;
begin
  Result := h;
end;

class function TGLiteComparablePairHeapMin.Handle2Ptr(h: THandle): PNode;
var
  p: PNode absolute h;
begin
  Result := p;
end;

function TGLiteComparablePairHeapMin.Comparator: TLess;
begin
  Result := @DoCompare;
end;

function TGLiteComparablePairHeapMin.GetEnumerator: TEnumerator;
begin
  Result.FCurrNode := nil;
  Result.FLeftmost := FindLeftmost;
  Result.FInCycle := False;
end;

function TGLiteComparablePairHeapMin.Reverse: TReverse;
begin
  Result.FHeap := @Self;
end;

function TGLiteComparablePairHeapMin.ToArray: TArray;
var
  I: SizeInt = 0;
  v: T;
begin
  System.SetLength(Result, Count);
  for v in Self do
    begin
      Result[I] := v;
      Inc(I);
    end;
end;

procedure TGLiteComparablePairHeapMin.Clear;
begin
  ClearTree;
end;

function TGLiteComparablePairHeapMin.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteComparablePairHeapMin.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteComparablePairHeapMin.Enqueue(const aValue: T);
begin
  RootMerge(NewNode(aValue));
end;

function TGLiteComparablePairHeapMin.Dequeue: T;
begin
  CheckEmpty;
  Result := DequeueItem;
end;

function TGLiteComparablePairHeapMin.TryDequeue(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := DequeueItem;
end;

function TGLiteComparablePairHeapMin.Peek: T;
begin
  CheckEmpty;
  Result := FRoot^.Data;
end;

function TGLiteComparablePairHeapMin.TryPeek(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FRoot^.Data;
end;

function TGLiteComparablePairHeapMin.Insert(const aValue: T): THandle;
var
  p: PNode;
begin
  p := NewNode(aValue);
  RootMerge(p);
  Result := Ptr2Handle(p);
end;

function TGLiteComparablePairHeapMin.PeekHandle: THandle;
begin
  CheckEmpty;
  Result := Ptr2Handle(FRoot);
end;

function TGLiteComparablePairHeapMin.TryPeekHandle(out aValue: THandle): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := Ptr2Handle(FRoot);
end;

function TGLiteComparablePairHeapMin.ValueOf(aHandle: THandle): T;
begin
  Result := Handle2Ptr(aHandle)^.Data;
end;

procedure TGLiteComparablePairHeapMin.Update(aHandle: THandle; const aValue: T);
begin
  CheckEmpty;
  UpdateNode(Handle2Ptr(aHandle), aValue);
end;

function TGLiteComparablePairHeapMin.Remove(aHandle: THandle): T;
begin
  CheckEmpty;
  Result := RemoveNode(Handle2Ptr(aHandle));
end;

function TGLiteComparablePairHeapMin.Merge(var aHeap: TGLiteComparablePairHeapMin): SizeInt;
begin
  if @Self = @aHeap then
    exit(0);
  Result := aHeap.Count;
  if Result > 0 then
    begin
      RootMerge(aHeap.FRoot);
      FCount += Result;
      aHeap.FCount := 0;
      aHeap.FRoot := nil;
    end;
end;

end.

