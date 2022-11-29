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

type

  TIntArrayHelper = type helper for TIntArray
  private
    function  GetLenght: SizeInt; inline;
    procedure SetLength(aValue: SizeInt); inline;
  public
    class function Construct(aLength: SizeInt; aFillValue: SizeInt = 0): TIntArray; static; inline;
    function  IsEmpty: Boolean; inline;
    function  Copy: TIntArray; inline;
    procedure Fill(aValue: SizeInt);
    property  Length: SizeInt read GetLenght write SetLength;
  end;

  TLGSmallIntHelper = type helper(TGSmallIntHelper) for SmallInt
    const INF_VALUE: SmallInt    = 32767;
    const NEGINF_VALUE: SmallInt = -32768;
  end;

  TLGLongIntHelper = type helper(TGLongIntHelper) for LongInt
    const INF_VALUE: LongInt    = 2147483647;
    const NEGINF_VALUE: LongInt = -2147483648;
  end;

  TLGInt64Helper = type helper(TGInt64Helper) for Int64
    const INF_VALUE: Int64    = 9223372036854775807;
    const NEGINF_VALUE: Int64 = -9223372036854775808;
  end;

  TLGSingleHelper = type helper(TGSingleHelper) for Single
    const INF_VALUE: Single    = 340282346638528859811704183484516925440.0;
    const NEGINF_VALUE: Single = -340282346638528859811704183484516925440.0;
  end;

  TLGDoubleHelper = type helper(TGDoubleHelper) for Double
    const INF_VALUE: Double    = 1.7976931348623157081e+308;
    const NEGINF_VALUE: Double = -1.7976931348623157081e+308;
  end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
  TLGExtendedHelper = type helper(TGExtendedHelper) for Extended
    const INF_VALUE: Extended    = 1.18973149535723176505e+4932;
    const NEGINF_VALUE: Extended = -1.18973149535723176505e+4932;
  end;
{$ENDIF}

{$IF DECLARED(Comp)}
  TLGCompHelper = type helper(TCompHelper) for Comp
    const INF_VALUE: Comp    = 9223372036854775807;
    const NEGINF_VALUE: Comp = -9223372036854775808;
  end;
{$ENDIF}

  TLGCurrencyHelper = type helper(TGCurrencyHelper) for Currency
    const INF_VALUE: Currency    = 922337203685477.5807;
    const NEGINF_VALUE: Currency = -922337203685477.5808;
  end;

  generic TGSimpleWeight<T> = record
    Weight: T;
    constructor Create(aValue: T);
  end;

  TDisjointSetUnion = record
  strict private
    FList: array of SizeInt;
    function  GetSize: SizeInt; inline;
    procedure SetSize(aValue: SizeInt);
  public
    procedure Clear; inline;
    procedure Reset;
  { values related to the same subset will have the same Tag }
    function  Tag(aValue: SizeInt): SizeInt;
    function  InSameSet(L, R: SizeInt): Boolean; inline;
    function  InDiffSets(L, R: SizeInt): Boolean; inline;
  { returns True and merges L and R, if L and R related to the different subsets, False otherwise }
    function  Join(L, R: SizeInt): Boolean;
    property  Size: SizeInt read GetSize write SetSize;
  end;

  TIntValue = record
    Value: SizeInt;
    constructor Create(aValue: SizeInt);
    property Key: SizeInt read Value write Value;
  end;

  TIntHashSet = record
  strict private
  type
    TTable = specialize TGLiteEquatableHashTable<SizeInt, TIntValue, SizeInt>;
    PEntry = TTable.PEntry;

  public
  type
    TEnumerator = record
    private
      FEnum: TTable.TEnumerator;
      function  GetCurrent: SizeInt; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: SizeInt read GetCurrent;
    end;

  strict private
    FTable: TTable;
    function  GetCount: SizeInt; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  ToArray: TIntArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    procedure Clear; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    function  Contains(aValue: SizeInt): Boolean; inline;
    function  Add(aValue: SizeInt): Boolean;
    function  AddAll(const a: array of SizeInt): SizeInt;
    function  AddAll(const s: TIntHashSet): SizeInt;
    function  Remove(aValue: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
  end;

  TOrdIntPair = packed record
  strict private
    FLess,
    FGreater: SizeInt;
  public
    class function HashCode(const aValue: TOrdIntPair): SizeInt; static;
    class function Equal(const L, R: TOrdIntPair): Boolean; static;
    constructor Create(L, R: SizeInt);
    function Key: TOrdIntPair;
    property Left: SizeInt read FLess;
    property Right: SizeInt read FGreater;
  end;

  POrdIntPair = ^TOrdIntPair;

  TIntPairSet = record
  strict private
  type
    TTable = specialize TGLiteHashTableLP<TOrdIntPair, TOrdIntPair, TOrdIntPair>;
  var
    FTable: TTable;
    function GetCount: SizeInt; inline;
  public
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure Clear; inline;
    function  Contains(L, R: SizeInt): Boolean; inline;
    function  Add(L, R: SizeInt): Boolean;
    function  Remove(L, R: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
  end;

  TIntNode = record
    Index,
    Data: SizeInt;
    class operator < (const L, R: TIntNode): Boolean; inline;
    constructor Create(aIndex, aData: SizeInt);
  end;

  { TGJoinableHashList: for internal use only; TEntry must provide
      property Key: SizeInt and numeric field Weight }
  generic TGJoinableHashList<TEntry> = record
  strict private
  type
    TTable = specialize TGLiteEquatableHashTable<SizeInt, TEntry, SizeInt>;
  public
  type
    TEnumerator = TTable.TEnumerator;
    PEntry      = ^TEntry;

  strict private
    FTable: TTable;
    function  GetCount: SizeInt; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure Add(const aValue: TEntry);
    procedure AddAll(const aList: TGJoinableHashList);
    procedure Remove(aValue: SizeInt); inline;
    property  Count: SizeInt read GetCount;
  end;

  TSimpleStack = record
  strict private
    Items: TIntArray;
    Top: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
  public
    constructor Create(aSize: SizeInt);
    function  ToArray: TIntArray; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    procedure Push(aValue: SizeInt); inline;
    function  Pop: SizeInt; inline;
    function  TryPop(out aValue: SizeInt): Boolean; inline;
    function  Peek: SizeInt; inline;
    function  TryPeek(out aValue: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;
  PSimpleStack = ^TSimpleStack;

  TCostItem = record
    Index: SizeInt;
    Cost: TCost;
    class operator < (const L, R: TCostItem): Boolean; inline;
    constructor Create(aIndex: SizeInt; aCost: TCost);
    property Key: SizeInt read Index;
  end;

  { TGWeightHelper }
  generic TGWeightHelper<TVertex, TWeight, TEdgeData, TEqRel> = class sealed
  public
  type
    TWeightArray  = array of TWeight;
    PWeight       = ^TWeight;
    TWArrayHelper = specialize TGArrayHelpUtil<TWeight>;

  strict private
    class function  CreateAndFill(aValue: TWeight; aSize: SizeInt): TWeightArray; static;
    class procedure Fill(var a: TWeightArray; aValue: TWeight); static;
    class function  ExtractCycle(aRoot, aLen: SizeInt; constref aTree: TIntArray): TIntArray; static;
  public
    class function  wMax(L, R: TWeight): TWeight; static; inline;
    class function  wMin(L, R: TWeight): TWeight; static; inline;
  type
    TWeightEdge = record
      Source,
      Destination: SizeInt;
      Weight:  TWeight;
      class operator < (const L, R: TWeightEdge): Boolean; inline;
      constructor Create(s, d: SizeInt; w: TWeight);
      function Edge: TIntEdge; inline;
    end;

    TWeightItem = record
      Index: SizeInt;
      Weight: TWeight;
      class operator < (const L, R: TWeightItem): Boolean; inline;
      constructor Create(aIndex: SizeInt; w: TWeight);
      property Key: SizeInt read Index;
    end;

    TRankItem = record
      Index: SizeInt;
      Rank,
      Weight: TWeight;
      class operator < (const L, R: TRankItem): Boolean; inline;
      constructor Create(aIndex: SizeInt; aRank, aWeight: TWeight);
    end;

    TApspCell = record
      Weight: TWeight;
      Predecessor: SizeInt;
      constructor Create(aWeight: TWeight; aPred: SizeInt);
    end;

    TGraph        = specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>;
    TEstimate     = function(const aSrc, aDst: TVertex): TWeight;
    TEdgeArray    = array of TWeightEdge;
    TWeightMatrix = array of array of TWeight;
    TApspMatrix   = array of array of TApspCell;

    { THungarian: hungarian weighted bipartite matching algorithm }
    THungarian = record
    strict private
      FGraph: TGraph;
      FBuffer: TIntArray;
      FMates,
      FParents,
      FQueue: PSizeInt;
      FPhi: TWeightArray;
      FWhites,
      FVisited: TBoolVector;
      FMatchCount: SizeInt;
      procedure Match(aNode, aMate: SizeInt); inline;
      procedure Init(aGraph: TGraph; const w, g: TIntArray; AsMax: Boolean);
      function  FindAugmentPathMin(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
      function  FindAugmentPathMax(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
      procedure AlternatePath(aRoot: SizeInt);
      function  TryAugmentMin(var aDelta: TWeight): SizeInt;
      function  TryAugmentMax(var aDelta: TWeight): SizeInt;
      procedure ExecuteMin;
      procedure ExecuteMax;
      function  CreateEdges: TEdgeArray;
    public
      function  MinMatching(aGraph: TGraph; const w, g: TIntArray): TEdgeArray;
      function  MaxMatching(aGraph: TGraph; const w, g: TIntArray): TEdgeArray;
    end;

    { TBfmt: Bellman-Ford-Moore SSSP algorithm with Tarjan subtree disassembly;
      copies graph into internal representation }
    TBfmt = record
    strict private
    type
      PNode  = ^TNode;
      PArc   = ^TArc;

      TArc = record
        Target: PNode;       // pointer to target node
        Weight: TWeight;
        constructor Create(aTarget: PNode; aWeight: TWeight);
      end;

      TNode = record
      private
        FirstArc: PArc;      // pointer to first incident arc
        Weight: TWeight;
        TreePrev,
        TreeNext,
        Parent: PNode;
        Level: SizeInt;
      end;

    public
      Nodes: array of TNode;
    strict private
      FArcs: array of TArc;
      FQueue: array of PNode;
      FInQueue,
      FActive: TBoolVector;
      FGraph: TGraph;
      FNodeCount: SizeInt;
      procedure CopyGraph(aDirected: Boolean);
      procedure SsspInit(aSrc: SizeInt);
    public
      constructor Create(aGraph: TGraph; aDirected: Boolean);
      function  IndexOf(aNode: PNode): SizeInt; inline;
      procedure Sssp(aSrc: SizeInt);
    end;
  { Dijkstra's algorithm: single-source shortest paths problem for non-negative weights  }
    class function  DijkstraSssp(g: TGraph; aSrc: SizeInt): TWeightArray; static;
    class function  DijkstraSssp(g: TGraph; aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray; static;
  { Dijkstra's pathfinding algorithm }
    class function  DijkstraPath(g: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray; static;
  { bidirectional Dijkstra's pathfinding algorithm }
    class function  BiDijkstraPath(g, gRev: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray; static;
  { A* pathfinding algorithm }
    class function  AStar(g: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray; static;
  {Wim Pijls, Henk Post: "Yet another bidirectional algorithm for shortest paths" }
    class function NBAStar(g, gRev: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray; static;
  { inplace Bellman-Ford-Moore algorithm }
    class function  BfmBase(g: TGraph; aSrc: SizeInt; out aTree: TIntArray; out aWeights: TWeightArray): SizeInt;
                    static;
  { inplace Bellman-Ford-Moore algorithm with Tarjan subtree disassembly,
    faster negative cycle detection }
    class function  BfmtBase(g: TGraph; aSrc: SizeInt; out aParents: TIntArray; out aWeights: TWeightArray): SizeInt;
                    static;
    class function  BfmtReweight(g: TGraph; out aWeights: TWeightArray): SizeInt; static;
  { negative cycle detection }
    class function  NegCycleDetect(g: TGraph; aSrc: SizeInt): TIntArray; static;
  { BFMT single-source shortest paths problem }
    class function  BfmtSssp(g: TGraph; aSrc: SizeInt; out aWeights: TWeightArray): Boolean; static;
    class function  BfmtSssp(g: TGraph; aSrc: SizeInt; out aPaths: TIntArray; out aWeights: TWeightArray): Boolean;
                    static;
  { BFMT pathfinding }
    class function  BfmtPath(g: TGraph; aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
                    static;
  { returns True if no negative cycle found, otherwise returns False and aPaths will contain
    single element with the index of an element on negative cycle }
    class function  FloydApsp(aGraph: TGraph; out aPaths: TApspMatrix): Boolean; static;
    class function  JohnsonApsp(aGraph: TGraph; out aPaths: TApspMatrix): Boolean; static;
    class function  BfmtApsp(aGraph: TGraph; aDirect: Boolean; out aPaths: TApspMatrix): Boolean; static;
  { creates array of length aLen and fills with InfWeight }
    class function  CreateWeightArray(aLen: SizeInt): TWeightArray; static;
  { creates array of length aLen and fills array with NegInfWeight }
    class function  CreateWeightArrayNI(aLen: SizeInt): TWeightArray; static;
  { creates array of length aLen and fills array with ZeroWeight }
    class function  CreateWeightArrayZ(aLen: SizeInt): TWeightArray; static;
  { resizes array to length aLen and fills array with aValue }
    class procedure ResizeAndFill(var a: TWeightArray; aLen: SizeInt; aValue: TWeight); static;
    class function  CreateWeightsMatrix(aGraph: TGraph): TWeightMatrix; static;
  { creates square matrix, fills main diagonal with (I, ZeroWeight) and
    fills other element with corresponding weights }
    class function  CreateAPSPMatrix(aGraph: TGraph): TApspMatrix; static;
  { warning: does not checks input }
    class function  ExtractMinPath(aSrc, aDst: SizeInt; const aMatrix: TApspMatrix): TIntArray; static;
  { returns bipartite matching of maximum cardinality and minimum weight;
    warning: does not checks if aGraph is bipartite }
    class function  MinBipMatch(aGraph: TGraph; const w, g: TIntArray): TEdgeArray; static;
  { returns bipartite matching of maximum cardinality and maximum weight;
    warning: does not checks if aGraph is bipartite }
    class function  MaxBipMatch(aGraph: TGraph; const w, g: TIntArray): TEdgeArray; static;
  end;

  generic TGBinHeapMin<T> = record // for internal use only
  strict private
  type
    THeap = array of T;

  var
    FBuffer: TIntArray;
    FHeap: THeap;
    FHandle2Index,
    FIndex2Handle: PSizeInt;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    procedure FloatUp(aIndex: SizeInt);
    procedure SiftDown(aIndex: SizeInt);
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    function  TryPeekPtr(out aValue: PItem): Boolean; inline;
    function  Dequeue: T; inline;
    function  Peek: T; inline;
    function  PeekPtr: PItem; inline;
    procedure Enqueue(aHandle: SizeInt; const aValue: T); inline;
    procedure Update(aHandle: SizeInt; const aNewValue: T); inline;
    function  GetItem(aHandle: SizeInt): T; inline;
    function  GetItemPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGPairHeapMin<T> = record // for internal use only
  strict private
  type
    PNode = ^TNode;
    TNode = record
      Prev,
      Child,
      Sibling: PNode;
      Data: T;
      function AddChild(aNode: PNode): PNode; inline;
    end;

    TNodeList = array of TNode;

  var
    FNodeList: TNodeList;
    FRoot: PNode;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  NewNode(const aValue: T; aHandle: SizeInt): PNode;
    function  DequeueItem: T;
    procedure RootMerge(aNode: PNode); inline;
    procedure ExtractNode(aNode: PNode);
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static;
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    function  TryPeekPtr(out aValue: PItem): Boolean; inline;
    function  Dequeue: T; inline;
    function  Peek: T; inline;
    function  PeekPtr: PItem; inline;
    procedure Enqueue(aHandle: SizeInt; const aValue: T); inline;
    procedure Update(aHandle: SizeInt; const aNewValue: T);
    procedure Remove(aHandle: SizeInt); inline;
    function  GetItem(aHandle: SizeInt): T; inline;
    function  GetItemPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGPairHeapMax<T> = record // for internal use only
  strict private
  type
    PNode = ^TNode;
    TNode = record
      Prev,
      Child,
      Sibling: PNode;
      Data: T;
      function AddChild(aNode: PNode): PNode; inline;
    end;

    TNodeList = array of TNode;

  var
    FNodeList: TNodeList;
    FRoot: PNode;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  NewNode(const aValue: T; aHandle: SizeInt): PNode;
    function  DequeueItem: T;
    procedure RootMerge(aNode: PNode); inline;
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static;
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    function  TryPeekPtr(out aValue: PItem): Boolean; inline;
    function  Dequeue: T; inline;
    function  Peek: T; inline;
    function  PeekPtr: PItem; inline;
    procedure Enqueue(aHandle: SizeInt; const aValue: T); inline;
    procedure Update(aHandle: SizeInt; const aNewValue: T);
    function  GetItem(aHandle: SizeInt): T; inline;
    function  GetItemPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  TINodePqMin = specialize TGPairHeapMin<TIntNode>;
  TINodePqMax = specialize TGPairHeapMax<TIntNode>;

  function CostMin(L, R: TCost): TCost; inline;
  function CostMax(L, R: TCost): TCost; inline;


