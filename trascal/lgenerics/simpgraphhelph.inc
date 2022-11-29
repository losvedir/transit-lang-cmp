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
  TNodeSearch = object
  protected
    FRecentBest: TIntArray;
    FStartTime: TDateTime;
    FTimeOut: Integer;
    FCancelled: Boolean;
    function TimeOut: Boolean; inline;
  end;

  TBPCliqueIsHelper = object(TNodeSearch) // BP -> bit-parallel
  strict private
    FMatrix: TBoolMatrix;
    FCurrSet: TBoolVector;
    FNodes: TIntArray;
    FOnFind: TOnSetFound;
    FCurrCount: SizeInt;
    procedure GreedyColor(const aCand: TBoolVector; var aColOrd, aColors: TIntArray);
    procedure Extend(var aCand: TBoolVector); // in Bron-Kerbosch terminlogy
    procedure Extend(var aSub, aCand: TBoolVector);
    procedure FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
    procedure SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
    procedure SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
  public
  { some variant of BB-MaxClique -
      San Segundo, P, Rodriguez-Losada, D., Jimenez, A.:
        "An exact bit-parallel algorithm for the maximum clique problem",
      Patrick Prosser: "Exact Algorithms for Maximum Clique: a computational study." }
    function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
  { executes MaxClique upon complement graph }
    function  MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
  { something like Tomita's Cliques on bit strings, except pivot maximizing -
      Etsuji Tomitaa, Akira Tanakaa, Haruhisa Takahashi:
        "The worst-case time complexity for generating all maximal cliques and
         computational experiments. }
    procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
  { executes ListCliques upon complement graph }
    procedure ListMIS(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
  end;

  TBPCliqueIsHelper256 = object(TNodeSearch) // BP -> bit-parallel
  strict private
    FMatrix: TBitMatrix256;
    FCurrSet: TBits256;
    FNodes: TIntArray;
    FOnFind: TOnSetFound;
    FCurrCount: SizeInt;
    procedure GreedyColor(const aCand: TBits256; var aColOrd, aColors: TIntArray);
    procedure Extend(var aCand: TBits256);
    procedure Extend(var aSub, aCand: TBits256);
    procedure FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
    procedure SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
    procedure SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
  public
    function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
    procedure ListMIS(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
  end;

  TMvcHelper = object
  private
    FVertexSet: TBoolVector;
    FOnFind: TOnSetFound;
    FNodeCount: SizeInt;
    procedure SetFound(const aSet: TIntArray; var aCancel: Boolean);
  public
    procedure Init(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
  end;

  TCliqueHelper = object(TNodeSearch)
  strict private
    FMatrix: TSkeleton;
    FCurrSet: TIntSet;
    FNodes: TIntArray;
    FOnFind: TOnSetFound;
    procedure GreedyColor(const aCand: TIntSet; var aColOrd, aColors: TIntArray);
    procedure Extend(var aCand: TIntSet);
    procedure Extend(var aSub, aCand: TIntSet);
  public
    function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnSetFound);
  end;

  TBPDomSetHelper = object(TNodeSearch) // BP -> bit-parallel
  strict private
    FMatrix: TBoolMatrix;
    FCurrSet: TBoolVector;
    FNodes: TIntArray;
    FCurrCount: SizeInt;
    procedure FillMatrix(aGraph: TGSimpleGraph; out aCand: TBoolVector);
    procedure Extend(const aCand, aTested: TBoolVector);
  public
    function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
  end;

  { TBPDomSetHelper256 }
  TBPDomSetHelper256 = object(TNodeSearch) // BP -> bit-parallel
  strict private
    FMatrix: TBitMatrix256;
    FCurrSet: TBits256;
    FNodes: TIntArray;
    FCurrCount: SizeInt;
    procedure FillMatrix(aGraph: TGSimpleGraph; out aCand: TBits256);
    procedure Extend(const aCand, aTested: TBits256);
  public
    function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
  end;

  TDomSetHelper = object(TNodeSearch)
  strict private
    FMatrix: TSkeleton;
    FCurrSet: TIntSet;
    procedure Extend(const aCand: TIntSet);
  public
    function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
  end;

  { TExactColor: a DSATUR-based branch and bound algorithm inspired by
    https://mat.tepper.cmu.edu/COLOR/solvers/trick.c by Michael Trick }
  TExactColor = object(TNodeSearch)
  strict private
  type
    PNode = ^TNode;
    TLink = PNode;
    PLink  = ^TLink;

    TNode = record
      Saturation,
      Degree,
      NeighbCount: Integer;
      EdgeList: PLink;
      AdjColors: array of Integer;
      constructor Create(aDegree, aUpperBound: SizeInt; aEdgeList: PLink);
      procedure NeighbPickColor(aColor: Integer); inline;
      procedure NeighbDropColor(aColor: Integer); inline;
    end;

  var
    FNodes: array of TNode;
    FEdgeList: array of TLink;
    FAchromatic: TBoolVector;
    FColorMap: TIntArray;
    FGraph: TGSimpleGraph;
    FLowBound,
    FUpBound,
    FNodeCount: SizeInt;
    procedure CreateStaticGraph;
    function  InitLowBound: SizeInt;
    procedure InitComplete;
    function  PickColor(aIndex, aColor: SizeInt): Boolean;
    procedure DropColor(aIndex, aColor: SizeInt);
    function  SelectNext(out aNode: SizeInt): Boolean;
    procedure DSatur(aMaxColor: SizeInt);
  public
    function Colorize(aGraph: TGSimpleGraph; aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
    function IsColorable(aGraph: TGSimpleGraph; aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
    function Complete(aGraph: TGSimpleGraph; aK: SizeInt; aTimeOut: Integer; var aColors: TIntArray): TTriLean;
  end;

  { TGreedyColorRlf }
  TGreedyColorRlf = record
  strict private
  type
    TNode = record
      Index,
      WDegree,
      Degree: SizeInt;
      class operator < (const L, R: TNode): Boolean;
      constructor Create(aIndex, aDegree: SizeInt);
    end;
    TQueue = specialize TGPairHeapMax<TNode>;
  public
    function Execute(aGraph: TGSimpleGraph; out aColors: TIntArray): SizeInt;
  end;

  { THamiltonSearch }
  THamiltonSearch = object
  strict private
  type
    TOnCheckNode = procedure (aIndex: SizeInt) of object;

  var
    FMatrix: TBoolMatrix;
    FVacant: TBoolVector;
    FStack: TSimpleStack;
    FPaths: PIntArrayVector;
    FOnCheckNode: TOnCheckNode;
    FSource,
    FNodeCount,
    FRequired,
    FFound: SizeInt;
    FStartTime: TDateTime;
    FTimeOut: Integer;
    FDone,
    FCancelled: Boolean;
    procedure Init(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer; pv: PIntArrayVector);
    function  TimeToFinish: Boolean; inline;
    function  SelectMin(const v: TBoolVector; out aValue: SizeInt): Boolean;
    procedure CheckIsCycle(aNode: SizeInt);
    procedure CheckIsPath(aNode: SizeInt); inline;
    procedure SearchFor(aNode: SizeInt);
    procedure ExecuteCycles;
    procedure ExecutePaths;
  public
    function  FindCycles(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
              pv: PIntArrayVector): Boolean;
    function  FindPaths(aGraph: TGSimpleGraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
              pv: PIntArrayVector): Boolean;
  end;

  { THKMatch: Hopcroft–Karp algorithm for maximum cardinality matching
    for bipartite graph - see en.wikipedia.org/wiki/Hopcroft–Karp_algorithm }
  THKMatch = record
  strict private
  type
    TArc = record
      Target: SizeInt; // index of target node
    end;

    TNode = record
      FirstArc,        // index of first incident arc in arcs array
      Distance,
      Mate: SizeInt;   // index of matched node
    end;

  const
    INF_DIST = High(SizeInt);
  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FWhites: array of SizeInt;
    FQueue: TIntArray;
    FNodeCount,
    FDummy: SizeInt;  // index of dummy node
    procedure Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
    function  Bfs: Boolean;
    function  Dfs(aRoot: SizeInt): Boolean;
    function  HopcroftKarp: TIntEdgeArray;
  public
    function  MaxMatching(aGraph: TGSimpleGraph; const w, g: TIntArray): TIntEdgeArray;
  end;

  { TBfsMatch: simple BFS matching algorithm for bipartite graph }
  TBfsMatch = record
  strict private
    FGraph: TGSimpleGraph;
    FMates,
    FParents,
    FQueue: TIntArray;
    FVisited: TBoolVector;
    FWhites: TBoolVector;
    FMatchCount: SizeInt;
    procedure Match(aNode, aMate: SizeInt); inline;
    procedure Init(aGraph: TGSimpleGraph; const w, g: TIntArray);
    function  FindAugmentPath(aRoot: SizeInt): SizeInt;
    procedure AlternatePath(aRoot: SizeInt);
    procedure BfsMatch;
    function  CreateEdges: TIntEdgeArray;
  public
    function  MaxMatching(aGraph: TGSimpleGraph; const w, g: TIntArray): TIntEdgeArray;
  end;

{ TEdMatchHelper: Edmonds algorithm for maximum cardinality matching }
  TEdMatchHelper = record
  strict private
    FGraph: TGSimpleGraph;
    FMates,
    FBase,
    FParents,
    FQueue: TIntArray;
    FVisited,
    FLcaUsed,
    FBlossoms: TBoolVector;
    FMatchCount: SizeInt;
    procedure Match(aNode, aMate: SizeInt); inline;
    procedure ClearBase; inline;
    procedure ClearParents; inline;
    function  Lca(L, R: SizeInt): SizeInt;
    procedure MarkPath(aNode, aBloss, aChild: SizeInt);
    function  FindAugmentPath(aRoot: SizeInt; out aLast: SizeInt): Boolean;
    procedure AlternatePath(aRoot: SizeInt);
    procedure EdMatch;
    procedure Init(aGraph: TGSimpleGraph);
  public
    function  Execute(aGraph: TGSimpleGraph): TIntEdgeArray;
  end;

  { TPcMatchHelper: Pape and Conradt general matching algorithm;
    Syslo, Deo, Kowalik "Discrete Optimization Algorithms: With Pascal Programs" }
  TPcMatchHelper = record
  strict private
    FGraph: TGSimpleGraph;
    FMates,
    FGrannies,
    FQueue: TIntArray;
    FInTree: TBoolVector;
    FMatchCount: SizeInt;
    procedure Match(aNode, aMate: SizeInt); inline;
    procedure FindAugmentPath(aSource: SizeInt);
    procedure Init(aGraph: TGSimpleGraph);
  public
    function  Execute(aGraph: TGSimpleGraph): TIntEdgeArray;
  end;

  { TNISimpMinCutHelper: some implemenation of Nagamochi-Ibaraki minimum cut algorithm }
  TNISimpMinCutHelper = record
  strict private
  type
    TNiEdge = record
      Target,
      Weight,
      ScanRank: SizeInt;
      Scanned: Boolean;
      constructor Create(aTarget, aWeight: SizeInt);
      property Key: SizeInt read Target;
    end;

    PNiEdge    = ^TNiEdge;
    TNiAdjList = specialize TGJoinableHashList<TNiEdge>;
    TQueue     = specialize TGPairHeapMax<TIntNode>;
    TEdgeQueue = specialize TGLiteQueue<TOrdIntPair>;

  var
    FGraph: array of TNiAdjList;
    FCuts: array of TIntSet;
    FQueue: TQueue;
    FEdgeQueue: TEdgeQueue;
    FExistNodes,
    FInQueue: TBoolVector;
    FBestSet: TIntSet;
    FBestCut: SizeInt;
    procedure ClearMarks; inline;
    procedure Init(aGraph: TGSimpleGraph; aCutsNeeded: Boolean);
    procedure ShrinkEdge(aSource, aTarget: SizeInt);
    procedure ScanFirstSearch;
    procedure Shrink;
  public
    function  Execute(aGraph: TGSimpleGraph): SizeInt;
    function  Execute(aGraph: TGSimpleGraph; out aCut: TIntSet): SizeInt;
  end;

  { TPlanarHelper: planarity testing algorithm and planar embedding construction
    based on the FMR Left-Right Planarity Test(de Fraysseix, Ossona de Mendez, and Rosenstiehl),
    well described in Ulrik Brandes: "The Left-Right Planarity Test" }
  TPlanarHelper = record
  private
  const
    LEFT_SIDE  = -1;
    RIGHT_SIDE = 1;
  type
    PNode = ^TNode;
    PArc  = ^TArc;

    TArc = record
      Source,
      Target: PNode;
      LowPt,
      NestingDepth: SizeInt;
      LowPtArc,
      Ref: PArc;
      Side: ShortInt;
      constructor Create(aSource, aTarget: PNode);
      function Sign: ShortInt;
    end;

    TArcCmp = class
      class function Less(L, R: PArc): Boolean; static;
    end;

    TNode = record
      FirstArc,
      Height: SizeInt;
      ParentArc: PArc;
      constructor Create(aFirstArc: SizeInt);
    end;

    TInterval = record
      LowA,
      HighA: PArc;
      constructor Create(aLowArc, aHighArc: PArc);
      function IsEmpty: Boolean; inline;
      function Conflicting(aArc: PArc): Boolean; inline;
    end;

    TConflictPair = record
      Left,
      Right: TInterval;
      constructor Create(const aRight: TInterval);
      procedure Swap; inline;
      function  Lowest: SizeInt; inline;
    end;
    PConflictPair = ^TConflictPair;

    TPairStack  = specialize TGLiteStack<TConflictPair>;
    TSortHelper = specialize TGBaseArrayHelper<PArc, TArcCmp>;
  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FSortedArcs: array of PArc;
    FLowPt2, FStackBottom: TIntArray;
    FPairStack: TPairStack;
    FRoots: TIntVector;
    FGraph: TGSimpleGraph;
    FPlanar: Boolean;
    function  IdxOfNode(aNode: PNode): SizeInt; inline;
    function  IdxOfArc(aArc: PArc): SizeInt; inline;
    procedure CreateDigraphR;
    procedure CreateDigraph;
    procedure Dfs1R(aRootIdx: SizeInt);
    procedure CreateOrientationR;
    procedure CreateOrientation;
    procedure SortAdjLists;
    procedure Dfs2R(aRootIdx: SizeInt);
    procedure AddConstraints(aParentArc, aArc: PArc);
    procedure TrimBackArcs(aNode: PNode);
    procedure TestLrPartitionR;
    procedure TestLrPartition;
    procedure CreateEmbeddingR(out aEmbed: TPlanarEmbedding);
    procedure CreateEmbedding(out aEmbed: TPlanarEmbedding);
    class function Min(L, R: SizeInt): SizeInt; static;
  public
    function  GraphIsPlanarR(aGraph: TGSimpleGraph): Boolean;
    function  GraphIsPlanarR(aGraph: TGSimpleGraph; out aEmbed: TPlanarEmbedding): Boolean;
    function  GraphIsPlanar(aGraph: TGSimpleGraph): Boolean;
    function  GraphIsPlanar(aGraph: TGSimpleGraph; out aEmbed: TPlanarEmbedding): Boolean;
  end;

  TSbWNode = record
    Index,
    WDegree,
    Degree: SizeInt;
    class operator < (constref L, R: TSbWNode): Boolean; inline;
    constructor Create(aIndex, aWDegree, aDegree: SizeInt);
  end;


