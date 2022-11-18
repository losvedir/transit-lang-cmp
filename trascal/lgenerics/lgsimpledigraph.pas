{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic simple directed graph implementation.                           *
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
unit lgSimpleDigraph;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  Classes, SysUtils, DateUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgQueue,
  lgVector,
  lgHashMap,
  lgSparseGraph,
  lgStrConst;

type
  TSortOrder = LGUtils.TSortOrder;

  { TGSimpleDigraph implements simple sparse directed graph based on adjacency lists;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGSimpleDigraph<TVertex, TEdgeData, TEqRel> = class(specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TReachabilityMatrix = record
    private
      FMatrix: TSquareBitMatrix;
      FIds: TIntArray;
      function  GetSize: SizeInt; inline;
      procedure Clear; inline;
    public
      constructor Create(const aMatrix: TSquareBitMatrix; const aIds: TIntArray);
      function  IsEmpty: Boolean; inline;
      function  Reachable(aSrc, aDst: SizeInt): Boolean; inline;
      property  Size: SizeInt read GetSize;
    end;

    { THamiltonSearch }
    THamiltonSearch = object
    strict private
    type
      TOnCheckNode  = procedure (aIndex: SizeInt) of object;

      TAdjList = record
        InDegree: SizeInt;
        OutList: TBoolVector;
        constructor Create(aDegree, aVertexCount: SizeInt; aAdjList: PAdjList);
      end;
      TMatrix = array of TAdjList;

    var
      FMatrix: TMatrix;
      FVacant: TBoolVector;
      FStack: TSimpleStack;
      FPaths: PIntArrayVector;
      FCheckNode: TOnCheckNode;
      FSource,
      FNodeCount,
      FRequired,
      FFound: SizeInt;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FDone,
      FCancelled: Boolean;
      procedure Init(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer; pv: PIntArrayVector);
      function  TimeToFinish: Boolean; inline;
      function  SelectMin(const v: TBoolVector; out aValue: SizeInt): Boolean;
      procedure CheckIsCycle(aNode: SizeInt);
      procedure CheckIsPath(aNode: SizeInt);
      procedure SearchFor(aNode: SizeInt);
      procedure ExecuteCycles;
      procedure ExecutePaths;
    public
      function  FindCycles(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
                pv: PIntArrayVector): Boolean;
      function  FindPaths(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
                pv: PIntArrayVector): Boolean;
    end;

  protected
    FReachabilityMatrix: TReachabilityMatrix;
    function  GetReachabilityValid: Boolean; inline;
    function  GetDensity: Double; inline;
    function  CreateSkeleton: TSkeleton;
    procedure AssignGraph(aGraph: TGSimpleDigraph);
    procedure AssignReverse(aGraph: TGSimpleDigraph);
    function  FindCycle(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
    function  CycleExists: Boolean;
    function  GetDomTree(aSrc: SizeInt; out aSize: SizeInt; out aPreds: TIntSetArray): TIntArray;
  { returns dominator tree, its size in aSize, array of incoming arcs in aPreds, numbering in DFS preorder,
    maps preorder->index and index->preorder in aOrd2Idx and aIdx2Ord }
    function  GetDomTreeSnca(aSrc: SizeInt; out aSize: SizeInt; out aPreds: TIntSetArray;
              out aOrd2Idx, aIdx2Ord: TIntArray): TIntArray;
    function  TestIsDomTree(const aTree: TIntArray; aSrc: SizeInt): Boolean;
    function  TopoSort: TIntArray;
    function  TopoSort(out a: TIntArray): Boolean;
    function  GetDagLongestPaths(aSrc: SizeInt): TIntArray;
    function  GetDagLongestPaths(aSrc: SizeInt; out aTree: TIntArray): TIntArray;
    function  SearchForStrongComponents(out aIds: TIntArray): SizeInt;
    function  GetReachabilityMatrix(const aScIds: TIntArray; aScCount: SizeInt): TReachabilityMatrix;
    function  DoAddVertex(const aVertex: TVertex; out aIndex: SizeInt): Boolean; override;
    procedure DoRemoveVertex(aIndex: SizeInt); override;
    function  DoAddEdge(aSrc, aDst: SizeInt; const aData: TEdgeData): Boolean; override;
    function  DoRemoveEdge(aSrc, aDst: SizeInt): Boolean; override;
    function  DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeData): Boolean; override;
    procedure DoWriteEdges(aStream: TStream; aOnWriteData: TOnWriteData); override;
    procedure EdgeContracting(aSrc, aDst: SizeInt); override;
  public
  type
    TIncomingArc = record
      Source: SizeInt;     //index of source vertex
      Data:  TEdgeData;
    end;

    TIncomingEnumerator = record
    private
      FGraph: TGSimpleDigraph;
      FTarget,
      FCurrIndex,
      FLastIndex,
      FInCount: SizeInt;
      FCurrArc: TIncomingArc;
      function  GetCurrent: TIncomingArc;
    public
      function  MoveNext: Boolean;
      property  Current: TIncomingArc read GetCurrent;
    end;

    TIncomingArcs = record
    private
      FGraph: TGSimpleDigraph;
      FTarget: SizeInt;
    public
      function GetEnumerator: TIncomingEnumerator;
    end;

    TDomTree = record
    private
    type
      TNode = record
        InTime,
        OutTime,
        Next: SizeInt;
      end;
      TNodeList = array of TNode;

    const
      INIT_LEN = 4;
      SDomTree = 'DomTree';

    var
      FNodeList: TNodeList;
      FTree: TIntArray;
      FRoot,
      FSize: SizeInt;
      function  GetCount: SizeInt; inline;
      procedure Dfs;
      function  GetIDom(aIndex: SizeInt): SizeInt;
      procedure Init(const aTree: TIntArray; aRoot: SizeInt);
    public
    type

      TDomSetEnumerator = record
      private
        FTree: TIntArray;
        FCurr: SizeInt;
      public
        function MoveNext: Boolean; inline;
        property Current: SizeInt read FCurr;
      end;

      TDominatedEnumerator = record
      private
        FNodeList: TNodeList;
        FCurr,
        FRootTime: SizeInt;
      public
        function MoveNext: Boolean;
        property Current: SizeInt read FCurr;
      end;

      TDomSet = record
      private
        FTree: TIntArray;
        FIndex: SizeInt;
      public
        function GetEnumerator: TDomSetEnumerator;
      end;

      TDominated = record
      private
        FNodeList: TNodeList;
        FIndex: SizeInt;
      public
        function GetEnumerator: TDominatedEnumerator;
      end;

    { returns True if the vertex with index aLeft dominates the vertex with index aRight }
      function Dominates(aLeft, aRight: SizeInt): Boolean;
    { enumerates dominators of the vertex with index aValue(excluding aValue) }
      function DomSetOf(aValue: SizeInt): TDomSet;
    { returns dominator set of the vertex with index aValue(excluding aValue) }
      function ExtractDomSet(aValue: SizeInt): TIntArray;
    { enumerates vertices dominated by the vertex with index aValue(excluding aValue) }
      function DominatedBy(aValue: SizeInt): TDominated;
    { returns vertex set dominated by the vertex with index aValue(excluding aValue) }
      function ExtractDominated(aValue: SizeInt): TIntArray;
    { returns index of the nearest vertex that dominates the vertices with indices
      aLeft and aRight, or -1, if there is no such vertex }
      function NcDom(aLeft, aRight: SizeInt): SizeInt;
    { returns True if the vertex with index aValue is in dominator tree }
      function InTree(aValue: SizeInt): Boolean;
    { index of immediate dominator of the vertex with index aIndex }
      property IDom[aIndex: SizeInt]: SizeInt read GetIDom; default;
      property Root: SizeInt read FRoot;
      property TreeSize: SizeInt read FSize;
      property Count: SizeInt read GetCount;
    end;

{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}

    procedure Clear; override;
    function  Clone: TGSimpleDigraph;
    function  Reverse: TGSimpleDigraph;
  { returns a subgraph induced by the vertices whose indices are contained in the array aVertexList }
    function  InducedSubgraph(const aVertexList: TIntArray): TGSimpleDigraph;
  { symmetric difference }
    procedure SetSymmDifferenceOf(aGraph: TGSimpleDigraph);
{**********************************************************************************************************
  structural management utilities
***********************************************************************************************************}

    function  InDegree(const aVertex: TVertex): SizeInt; inline;
    function  InDegreeI(aIndex: SizeInt): SizeInt;
    function  OutDegree(const aVertex: TVertex): SizeInt; inline;
    function  OutDegreeI(aIndex: SizeInt): SizeInt;
    function  Degree(const aVertex: TVertex): SizeInt; inline;
    function  DegreeI(aIndex: SizeInt): SizeInt;
    function  Isolated(const aVertex: TVertex): Boolean; inline;
    function  IsolatedI(aIndex: SizeInt): Boolean; inline;
    function  IsSource(const aVertex: TVertex): Boolean; inline;
    function  IsSourceI(aIndex: SizeInt): Boolean;
    function  IsSink(const aVertex: TVertex): Boolean; inline;
    function  IsSinkI(aIndex: SizeInt): Boolean;
    function  SourceCount: SizeInt;
    function  SinkCount: SizeInt;
  { enumerates incoming arcs, slow }
    function  IncomingArcs(const aVertex: TVertex): TIncomingArcs;
    function  IncomingArcsI(aIndex: SizeInt): TIncomingArcs;
  { checks whether the aDst is reachable from the aSrc(each vertex is reachable from itself) }
    function  PathExists(const aSrc, aDst: TVertex): Boolean; inline;
    function  PathExistsI(aSrc, aDst: SizeInt): Boolean;
  { returns the list of indices of the vertices reachable from aSource(including aSource) }
    function  ReachableFrom(const aSource: TVertex): TIntArray; inline;
    function  ReachableFromI(aSrcIdx: SizeInt): TIntArray;
  { checks whether exists any cycle in subgraph that reachable from a aSource;
    if True then aCycle will contain indices of the vertices of that cycle }
    function  ContainsCycle(const aSource: TVertex; out aCycle: TIntArray): Boolean; inline;
    function  ContainsCycleI(aSrcIdx: SizeInt; out aCycle: TIntArray): Boolean;
    function  ContainsEulerianCycle: Boolean;
    function  FindEulerianCycle: TIntArray;
  { checks whether the graph is stongly connected; an empty graph is considered disconnected }
    function  IsStrongConnected: Boolean;
  { returns count of the strong connected components; the corresponding element aCompIds
    will contain its component index; used Gabow's algorithm }
    function  FindStrongComponents(out aCompIds: TIntArray): SizeInt;
  { returns array of indices of a strongly connected component that contains aVertex }
    function  GetStrongComponent(const aVertex: TVertex): TIntArray; inline;
    function  GetStrongComponentI(aIndex: SizeInt): TIntArray;
  { creates internal reachability matrix }
    procedure BuildReachabilityMatrix;
  { attempts to create an internal reachability matrix using precomputed FindStrongComponents results;
    todo: doubtful method? }
    function  TryBuildReachabilityMatrix(const aScIds: TIntArray; aScCount: SizeInt): Boolean;
  { returns True, radius and diameter, if graph is strongly connected, False otherwise }
    function  FindMetrics(out aRadius, aDiameter: SizeInt): Boolean;
  { returns array of indices of the central vertices, if graph is strongly connected, nil otherwise }
    function  FindCenter: TIntArray;
  { returns array of indices of the peripheral vertices, if graph is strongly connected, nil otherwise }
    function  FindPeripheral: TIntArray;
  { returns an array containing a chain of vertex indices of the found shortest(in the sense of "number of edges")
    path, or an empty array if the path does not exists }
    function ShortestPath(const aSrc, aDst: TVertex): TIntArray; inline;
    function ShortestPathI(aSrc, aDst: SizeInt): TIntArray;
{**********************************************************************************************************
  flowgraph utilities
***********************************************************************************************************}

  { returns True if graph is flowgraph, False otherwise;
    raises an exception if it does not contain the vertex aSource;
    a ﬂowgraph G = (V, A, r) is a directed graph where every vertex in V is reachable
    from a distinguished root vertex r }
    function  IsFlowGraph(const aSource: TVertex): Boolean; inline;
    function  IsFlowGraphI(aSrcIdx: SizeInt): Boolean;
  { same as above, and besides, returns a list of unreached vertices in aMissed }
    function  IsFlowGraph(const aSource: TVertex; out aMissed: TIntArray): Boolean; inline;
    function  IsFlowGraphI(aSrcIdx: SizeInt; out aMissed: TIntArray): Boolean;
  { returns dominator tree and its size in aSize of a flowgraph rooted by aSource;
    raises an exception if it does not contain the vertex aSource;
    each element aTree[J] is immediate dominator of J'th vertex or -1, if J'th vertex is root,
    or is unreachable from aSource; used amazingly simple iterative algorithm from
    Cooper, Harvey and Kennedy "A Simple, Fast Dominance Algorithm" }
    function  FindDomTree(const aSource: TVertex; out aSize: SizeInt): TIntArray; inline;
    function  FindDomTreeI(aSrcIdx: SizeInt; out aSize: SizeInt): TIntArray;
  { returns dominator tree and its size in aSize of a flowgraph rooted by aSource;
    raises an exception if it does not contain the vertex aSource;
    each element aTree[J] is immediate dominator of J'th vertex or -1, if J'th vertex is root,
    or is unreachable from aSource; used Georgiadis's Semi-NCA algorithm }
    function  FindDomTreeSnca(const aSource: TVertex; out aSize: SizeInt): TIntArray; inline;
    function  FindDomTreeSncaI(aSrcIdx: SizeInt; out aSize: SizeInt): TIntArray;
  { returns True if aTree is dominator tree rooted by aSource;
    todo: this checks only necessity but not sufficiency }
    function  IsDomTree(const aTree: TIntArray; constref aSource: TVertex): Boolean; inline;
    function  IsDomTreeI(const aTree: TIntArray; aSrcIdx: SizeInt): Boolean;
  { extracts Dom(aVertex) from dominator tree aTree, including aVertex }
    function  ExtractDomSet(const aVertex: TVertex; const aDomTree: TIntArray): TIntArray; inline;
    function  ExtractDomSetI(aVertexIdx: SizeInt; const aDomTree: TIntArray): TIntArray;
  { used iterative algorithm }
    function  CreateDomTree(const aSource: TVertex): TDomTree; inline;
    function  CreateDomTreeI(aSrcIdx: SizeInt): TDomTree;
  { used Semi-NCA algorithm }
    function  CreateDomTreeSnca(const aSource: TVertex): TDomTree; inline;
    function  CreateDomTreeSncaI(aSrcIdx: SizeInt): TDomTree;
  { returns dominance frontiers and dominator tree in aDomTree(used Semi-NCA algorithm);
    raises an exception if it does not contain the vertex aSource }
    function  FindDomFrontiers(const aSource: TVertex; out aDomTree: TDomTree): TIntMatrix; inline;
    function  FindDomFrontiersI(aSrcIdx: SizeInt; out aDomTree: TDomTree): TIntMatrix;

{**********************************************************************************************************
  DAG utilities
***********************************************************************************************************}

  { returns array of vertex indices in topological order, does not performs any acyclic checks;
    sort order soAsc implies that all arcs are directed from left to right,
    soDesc - on the contrary, from right to left }
    function  TopologicalSort(aOrder: TSortOrder = soAsc): TIntArray;
  { returns True and array of vertex indices in topological order in aSorted,
    if a graph is acyclic, False and first found cycle otherwise;
    sort order soAsc implies that all arcs are directed from left to right,
    soDesc - from right to left }
    function  TopologicalSort(out aSorted: TIntArray; aOrder: TSortOrder = soAsc): Boolean;
    function  IsTopoSorted(const aTestSet: TIntArray; aSortOrder: TSortOrder = soAsc): Boolean;
    function  IsDag: Boolean;
  { returns an array containing in the corresponding components the length of the longest path
    from aSrc to it (in sense 'edges count'), or -1 if it is unreachable from aSrc if a graph is acyclic,
    otherwise returns nil }
    function  DagLongestPathsMap(const aSrc: TVertex): TIntArray; inline;
    function  DagLongestPathsMapI(aSrc: SizeInt): TIntArray;
  { same as above and in aPathTree returns paths or cycle }
    function  DagLongestPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TIntArray; inline;
    function  DagLongestPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TIntArray;
  { returns an array containing in the corresponding components the length of
    the longest path starting with it(in sense 'edges count'), if a graph is acyclic,
    otherwise returns nil }
    function  DagLongestPaths: TIntArray;
{**********************************************************************************************************
  some NP-hard problem utilities
***********************************************************************************************************}

  { tries to return in aCycles the specified number of Hamiltonian cycles, starting from the vertex aSource;
    if aCount <= 0, then all cycles are returned; if aCount > 0, then
    Min(aCount, total) cycles are returned; aTimeOut specifies the timeout in seconds;
    at the end of the timeout False will be returned }
    function  FindHamiltonCycles(const aSource: TVertex; aCount: SizeInt; out aCycles: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean; inline;
    function  FindHamiltonCyclesI(aSourceIdx, aCount: SizeInt; out aCycles: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns True if aTestCycle is Hamiltonian cycle starting from the vertex with index aSourceIdx }
    function  IsHamiltonCycle(const aTestCycle: TIntArray; aSourceIdx: SizeInt): Boolean;
  { tries to return in aPaths the specified number of Hamiltonian paths
    from the vertex aSrc; if aCount <= 0, then all paths are returned;
    if aCount > 0, then Min(aCount, total) cycles are returned; aTimeOut specifies
    the timeout in seconds; at the end of the timeout False will be returned }
    function  FindHamiltonPaths(const aSrc: TVertex; aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean; inline;
    function  FindHamiltonPathsI(aSrcIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns True if aTestPath is Hamiltonian path starting from the vertex with index aSourceIdx }
    function  IsHamiltonPath(const aTestPath: TIntArray; aSrcIdx: SizeInt): Boolean;
{**********************************************************************************************************
  properties
***********************************************************************************************************}

    property  ReachabilityValid: Boolean read GetReachabilityValid;
    property  Density: Double read GetDensity;
  end;

  { TGFlowChart: simple outline;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGFlowChart<TVertex, TEqRel> = class(specialize TGSimpleDigraph<TVertex, TDummy, TEqRel>)
  private
    procedure ReadData(aStream: TStream; out aValue: TDummy);
    procedure WriteData(aStream: TStream; const aValue: TDummy);
  public
    function  Clone: TGFlowChart;
    function  Reverse: TGFlowChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TGFlowChart;
    procedure SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
    procedure SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
    procedure SetUnionOf(aChart: TGFlowChart);
    procedure SetIntersectionOf(aChart: TGFlowChart);
  end;

  { TGDigraphDotWriter }

  generic TGDigraphDotWriter<TVertex, TEdgeData, TEqRel> = class(
    specialize TGAbstractDotWriter<TVertex, TEdgeData, TEqRel>)
  protected
    procedure WriteEdges(aGraph: TGraph; aList: TStrings) override;
  public
    constructor Create;
  end;

  { TIntFlowChart }

  TIntFlowChart = class(specialize TGFlowChart<Integer, Integer>)
  protected
    procedure WriteVertex(aStream: TStream; const aValue: Integer);
    procedure ReadVertex(aStream: TStream; out aValue: Integer);
  public
    function  Clone: TIntFlowChart;
    function  Reverse: TIntFlowChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TIntFlowChart;
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
  { adds numbers in range [aFrom, aTo] as vertices, returns count of added vertices }
    function  AddVertexRange(aFrom, aTo: Integer): Integer;
  { treats aVertexList as list of the pairs of source-target, last odd element ignored;
    returns count of added edges; }
    function  AddEdges(const aVertexList: array of Integer): Integer;
  end;

  TIntFlowChartDotWriter = class(specialize TGDigraphDotWriter<Integer, TDummy, Integer>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string; override;
  end;

  { TStrFlowChart
    warning: SaveToStream limitation for max string length = High(SmallInt) }
  TStrFlowChart = class(specialize TGFlowChart<string, string>)
  protected
    procedure WriteVertex(aStream: TStream; const aValue: string);
    procedure ReadVertex(aStream: TStream; out aValue: string);
  public
    function  Clone: TStrFlowChart;
    function  Reverse: TStrFlowChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TStrFlowChart;
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
  { treats aVertexList as list of the pairs of source-target, last odd element ignored;
    returns count of added edges; }
    function  AddEdges(const aVertexList: array of string): Integer;
  end;

  TStrFlowChartDotWriter = class(specialize TGDigraphDotWriter<string, TDummy, string>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string; override;
  end;

  { TGWeightedDigraph implements simple sparse directed weighted graph based on adjacency lists;

      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean;

      TEdgeData must provide field/property/function Weight: TWeight;

      TWeight must be one of predefined signed numeric types;
      properties MinValue, MaxValue used as infinity weight values }
  generic TGWeightedDigraph<TVertex, TWeight, TEdgeData, TEqRel> = class(
     specialize TGSimpleDigraph<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TWeightHelper = specialize TGWeightHelper<TVertex, TWeight, TEdgeData, TEqRel>;

  public
  type
    TWeightItem   = TWeightHelper.TWeightItem;
    TWeightArray  = TWeightHelper.TWeightArray;
    TEstimate     = TWeightHelper.TEstimate;
    TWeightEdge   = TWeightHelper.TWeightEdge;
    TEdgeArray    = array of TWeightEdge;
    TWeightMatrix = TWeightHelper.TWeightMatrix;
    TApspCell     = TWeightHelper.TApspCell;
    TApspMatrix   = TWeightHelper.TApspMatrix;

  protected
    function  CreateEdgeArray: TEdgeArray;
    procedure GetDagMinPaths(aSrc: SizeInt; var aWeights: TWeightArray);
    procedure GetDagMinPaths(aSrc: SizeInt; var aTree: TIntArray; var aWeights: TWeightArray);
    function  GetDagMaxPaths(aSrc: SizeInt): TWeightArray;
    function  GetDagMaxPaths(aSrc: SizeInt; out aTree: TIntArray): TWeightArray;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function InfWeight: TWeight; static; inline;
    class function NegInfWeight: TWeight; static; inline;
    class function wMin(L, R: TWeight): TWeight; static; inline;
    class function wMax(L, R: TWeight): TWeight; static; inline;
    class function TotalWeight(const aEdges: TEdgeArray): TWeight; static;
    class function EdgeArray2IntEdgeArray(const a: TEdgeArray): TIntEdgeArray; static;
  { returns True if exists arc with negative weight }
    function ContainsNegWeightEdge: Boolean;
  { checks whether exists any negative weight cycle in subgraph that reachable from a aRoot;
    if True then aCycle will contain indices of the vertices of the cycle;
    raises an exception if aRoot does not exist }
    function ContainsNegCycle(const aRoot: TVertex; out aCycle: TIntArray): Boolean; inline;
    function ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function Clone: TGWeightedDigraph;
    function Reverse: TGWeightedDigraph;
    function InducedSubgraph(const aVertexList: TIntArray): TGWeightedDigraph;
{**********************************************************************************************************
  shortest path problem utilities
***********************************************************************************************************}

  { returns the weights of paths of minimal weight from a given vertex to the remaining
    vertices(SSSP), the weights of all arcs MUST be nonnegative;
    the result contains in the corresponding component the weight of the path to the vertex or
    InfWeight if the vertex is unreachable; used Dijkstra's algorithm;
    raises an exception if aSrc does not exist }
    function MinPathsMap(const aSrc: TVertex): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths }
    function MinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { returns the vertex path of minimal weight from a aSrc to aDst if it exists(pathfinding);
    the weights of all arcs MUST be nonnegative;
    returns weight of the path or InfWeight if the vertex is unreachable in aWeight;
    used Dijkstra's algorithm; raises an exception if aSrc or aDst does not exist }
    function MinPath(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray; inline;
    function MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
    { returns the vertex path of minimal weight from a aSrc to aDst if it exists(pathfinding);
      the weights of all edges MUST be nonnegative;
      the required aRev is a reverse graph;
      returns weight of the path or InfWeight if the vertex is unreachable in aWeight;
      used bidirectional Dijkstra's algorithm; raises an exception if aSrc or aDst does not exist }
    function MinPathBiDir(const aSrc, aDst: TVertex; aRev: TGWeightedDigraph; out aWeight: TWeight): TIntArray;
    function MinPathBiDirI(aSrc, aDst: SizeInt; aRev: TGWeightedDigraph; out aWeight: TWeight): TIntArray;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the weights of all arcs MUST be nonnegative; used A* algorithm if aEst <> nil;
    raises an exception if aSrc or aDst does not exist }
    function MinPathAStar(const aSrc, aDst: TVertex; out aWeight: TWeight; aEst: TEstimate): TIntArray; inline;
    function MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the required aRev is a reverse graph;
    the weights of all edges MUST be nonnegative; used NBA* algorithm if aEst <> nil;
    raises an exception if aSrc or aDst does not exist }
    function MinPathNBAStar(const aSrc, aDst: TVertex; aRev: TGWeightedDigraph; out aWeight: TWeight;
                            aEst: TEstimate): TIntArray; inline;
    function MinPathNBAStarI(aSrc, aDst: SizeInt; aRev: TGWeightedDigraph; out aWeight: TWeight;
                            aEst: TEstimate): TIntArray;
  { returns False if exists negative weighted cycle, otherwise returns the vertex path
    of minimal weight from a aSrc to aDst in aPath, if exists, and its weight in aWeight;
    to distinguish 'unreachable' and 'negative cycle': in case negative cycle aWeight returns ZeroWeight,
    but InfWeight if aDst unreachable; used BFMT algorithm }
    function FindMinPath(const aSrc, aDst: TVertex; out aPath: TIntArray; out aWeight: TWeight): Boolean; inline;
    function FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
  { returns False if exists negative weight cycle reachable from aSrc,
    otherwise returns the weights of paths of minimal weight from a given vertex to the remaining
    vertices(SSSP); an aWeights will contain in the corresponding component the weight of the path
    to the vertex or InfWeight if the vertex is unreachable; used BFMT algorithm;
    raises an exception if aSrc does not exist  }
    function FindMinPathsMap(const aSrc: TVertex; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
  { same as above and in aPaths returns paths,
    if there is a negative weight cycle, then aPaths will contain that cycle }
    function FindMinPathsMap(const aSrc: TVertex; out aPaths: TIntArray; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aPaths: TIntArray; out aWeights: TWeightArray): Boolean;
  { creates a matrix of weights of arcs }
    function CreateWeightsMatrix: TWeightMatrix; inline;
  { returns True and the shortest paths between all pairs of vertices in matrix aPaths
    if non empty and no negative weight cycles exist,
    otherwise returns False and if negative weight cycle exists then in single cell of aPaths
    returns index of the vertex from which this cycle is reachable }
    function FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
  { raises an exception if aSrc or aDst does not exist }
    function ExtractMinPath(const aSrc, aDst: TVertex; const aPaths: TApspMatrix): TIntArray; inline;
    function ExtractMinPathI(aSrc, aDst: SizeInt; const aPaths: TApspMatrix): TIntArray;
  { returns False if is empty or exists negative weight cycle reachable from aVertex,
    otherwise returns True and the weighted eccentricity of the aVertex in aValue }
    function FindEccentricity(const aVertex: TVertex; out aValue: TWeight): Boolean; inline;
    function FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
  { returns False if is not strongly connected or exists negative weight cycle,
    otherwise returns True and weighted radius and diameter of the graph }
    function FindWeightedMetrics(out aRadius, aDiameter: TWeight): Boolean;
  { returns False if is not strongly connected or exists negative weight cycle,
    otherwise returns True and indices of the central vertices in aCenter }
    function FindWeightedCenter(out aCenter: TIntArray): Boolean;
{**********************************************************************************************************
  DAG utilities
***********************************************************************************************************}
  { SSSP for an acyclic graph;
    returns an array containing in the corresponding components the minimum weight of
    the path from aSrc to it, or InfWeight if it is unreachable, if graph is acyclic,
    otherwise returns nil }
    function DagMinPathsMap(const aSrc: TVertex): TWeightArray; inline;
    function DagMinPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths or cycle }
    function DagMinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function DagMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { APSP for acyclic graph }
    function FindDagAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
  { returns an array containing in the corresponding components the maximum weight of
    the path from aSrc to it, or NegInfWeight if it is unreachable from aSrc, if graph is acyclic,
    otherwise returns nil }
    function DagMaxPathsMap(const aSrc: TVertex): TWeightArray; inline;
    function DagMaxPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths, or cycle }
    function DagMaxPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function DagMaxPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { returns an array containing in the corresponding components the maximal weight of
    the path starting with it, if graph is acyclic, otherwise returns nil }
    function DagMaxPaths: TWeightArray;
  end;

  { TGDirectInt64Net specializes TWeight with Int64 }
  generic TGDirectInt64Net<TVertex, TEdgeData, TEqRel> = class(
     specialize TGWeightedDigraph<TVertex, Int64, TEdgeData, TEqRel>)
  public
  type
    TWeight = Int64;

  protected
  const
    MAX_WEIGHT = High(Int64);
    MIN_WEIGHT = Low(Int64);

    {$I MaxFlowH.inc}
  public
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function Clone: TGDirectInt64Net;
    function Reverse: TGDirectInt64Net;
    function InducedSubgraph(const aVertexList: TIntArray): TGDirectInt64Net;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns True and the matching of the maximum cardinality and minimum weight
    if graph is bipartite, otherwise returns False }
    function FindMinWeightBipMatch(out aMatch: TEdgeArray): Boolean;
  { returns True and the matching of the maximum cardinality and maximum weight
    if graph is bipartite, otherwise returns False }
    function FindMaxWeightBipMatch(out aMatch: TEdgeArray): Boolean;
{**********************************************************************************************************
  networks utilities treat the weight of the arc as its capacity
***********************************************************************************************************}
  type
    TNetworkState = (nsOk, nsTrivial, nsInvalidSource, nsInvalidSink, nsNegCapacity, nsSinkUnreachable);

    function GetNetworkState(const aSource, aSink: TVertex): TNetworkState; inline;
    function GetNetworkStateI(aSrcIdx, aSinkIdx: SizeInt): TNetworkState;
  { returns state of the network with aSource as source and aSink as sink;
    returns maximum flow through the network in aFlow, if result = nsOk, 0 otherwise;
    used push/relabel algorithm }
    function FindMaxFlowPr(const aSource, aSink: TVertex; out aFlow: TWeight): TNetworkState; inline;
    function FindMaxFlowPrI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight): TNetworkState;
  { returns state of network with aSource as source and aSink as sink;
    returns maximum flow through the network in aFlow and flows through the arcs
    in array a, if result = nsOk, 0 and nil otherwise; used push/relabel algorithm }
    function FindMaxFlowPr(const aSource, aSink: TVertex; out aFlow: TWeight; out a: TEdgeArray): TNetworkState;
             inline;
    function FindMaxFlowPrI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight; out a: TEdgeArray): TNetworkState;
  { returns state of network with aSource as source and aSink as sink;
    param aFlow specifies required flow > 0; returns flow through the network
    as (Min(required flow, maximum flow)) in aFlow and flows through the arcs
    in array a if result = nsOk and aFlow > 0, 0 and nil otherwise; used push/relabel algorithm }
    function FindFlowPr(const aSource, aSink: TVertex; var aFlow: TWeight; out a: TEdgeArray): TNetworkState;
             inline;
    function FindFlowPrI(aSrcIdx, aSinkIdx: SizeInt; var aFlow: TWeight; out a: TEdgeArray): TNetworkState;
  { returns state of the network with aSource as source and aSink as sink;
    returns maximum flow through the network in aFlow, if result = nsOk, 0 otherwise;
    used Dinitz's algorithm with recursive DFS }
    function FindMaxFlowD(const aSource, aSink: TVertex; out aFlow: TWeight): TNetworkState; inline;
    function FindMaxFlowDI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight): TNetworkState;
  { returns state of network with aSource as source and aSink as sink;
    returns maximum flow through the network in aFlow and flows through the arcs
    in array a, if result = nsOk, 0 and nil otherwise; used Dinitz's algorithm with recursive DFS }
    function FindMaxFlowD(const aSource, aSink: TVertex; out aFlow: TWeight; out a: TEdgeArray): TNetworkState;
             inline;
    function FindMaxFlowDI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight; out a: TEdgeArray): TNetworkState;
  { returns state of network with aSource as source and aSink as sink;
    param aFlow specifies required flow > 0; returns flow through the network
    as (Min(required flow, maximum flow)) in aFlow and flows through the arcs
    in array a if result = nsOk and aFlow > 0, 0 and nil otherwise;
    used Dinitz's algorithm with recursive DFS }
    function FindFlowD(const aSource, aSink: TVertex; var aFlow: TWeight; out a: TEdgeArray): TNetworkState;
             inline;
    function FindFlowDI(aSrcIdx, aSinkIdx: SizeInt; var aFlow: TWeight; out a: TEdgeArray): TNetworkState;
    {  }
    function IsFeasibleFlow(const aSource, aSink: TVertex; aFlow: TWeight; const a: TEdgeArray): Boolean;
    function IsFeasibleFlowI(aSrcIdx, aSinkIdx: SizeInt; aFlow: TWeight; const a: TEdgeArray): Boolean;

  type
    //s-t vertex partition
    TStCut = record
      S,
      T: TIntArray;
    end;

  { returns state of the network with aSource as source and aSink as sink;
    returns value of the minimum cut in aValue and vertex partition in aCut,
    if result = nsOk, otherwise 0 and empty partition; used push/relabel algorithm }
    function FindMinSTCutPr(const aSource, aSink: TVertex; out aValue: TWeight; out aCut: TStCut): TNetworkState;
    function FindMinSTCutPrI(aSrcIdx, aSinkIdx: SizeInt; out aValue: TWeight; out aCut: TStCut): TNetworkState;
  { returns state of the network with aSource as source and aSink as sink;
    returns value of the minimum cut in aValue and vertex partition in aCut,
    if result = nsOk, otherwise 0 and empty partition; used Dinitz's algorithm with recursive DFS }
    function FindMinSTCutD(const aSource, aSink: TVertex; out aValue: TWeight; out aCut: TStCut): TNetworkState;
    function FindMinSTCutDI(aSrcIdx, aSinkIdx: SizeInt; out aValue: TWeight; out aCut: TStCut): TNetworkState;
  end;

  TCostPair = record
    Weight: Int64;
    Cost: TCost;
    constructor Create(aWeight: Int64; aCost: TCost);
  end;

  { TGCostedInt64Net:  TEdgeData must provide arc cost function -
      field/property/function Cost: TCost; }
  generic TGCostedInt64Net<TVertex, TEdgeData, TEqRel> = class(
    specialize TGDirectInt64Net<TVertex, TEdgeData, TEqRel>)
  protected
    {$I McfH.inc}
  public
{**********************************************************************************************************
 class management utilities
***********************************************************************************************************}
   function Clone: TGCostedInt64Net;
   function Reverse: TGCostedInt64Net;
   function InducedSubgraph(const aVertexList: TIntArray): TGCostedInt64Net;

  type
    TMcfState = (mcfOk, mcfNoFlowRequired, mcfInvalidNet, mcfNegCycle);

  { negative costs allows;
    param aReqFlow specifies required flow > 0(MAX_WEIGHT means maximum flow is required);
    returns mcfOk if aNeedFlow > 0 and network valid and no negative cycle found,
    returns flow = min(aReqFlow, maxflow) in aReqFlow and total flow cost in aTotalCost;
    used Busacker-Gowen's algorithm }
    function FindMinCostFlowSsp(const aSource, aSink: TVertex; var aReqFlow: TWeight;
             out aTotalCost: TCost): TMcfState; inline;
    function FindMinCostFlowSspI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
             out aTotalCost: TCost): TMcfState;
  { same as above and in addition returns flows through the arcs in array aArcFlows }
    function FindMinCostFlowSsp(const aSource, aSink: TVertex; var aReqFlow: TWeight; out aTotalCost: TCost;
             out aArcFlows: TEdgeArray): TMcfState; inline;
    function FindMinCostFlowSspI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight; out aTotalCost: TCost;
             out aArcFlows: TEdgeArray): TMcfState;
  { negative costs allows;
    param aReqFlow specifies the required flow > 0(MAX_WEIGHT means maximum flow is required);
    returns mcfOk if aNeedFlow > 0 and network valid and no negative cycle found,
    returns flow = min(aReqFlow, maxflow) in aReqFlow and total flow cost in aTotalCost;
    used cost scaling algorithm }
    function FindMinCostFlowCs(const aSource, aSink: TVertex; var aReqFlow: TWeight;
             out aTotalCost: TCost): TMcfState; inline;
    function FindMinCostFlowCsI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
             out aTotalCost: TCost): TMcfState;
  { same as above and in addition returns flows through the arcs in array aArcFlows }
    function FindMinCostFlowCs(const aSource, aSink: TVertex; var aReqFlow: TWeight; out aTotalCost: TCost;
             out aArcFlows: TEdgeArray): TMcfState; inline;
    function FindMinCostFlowCsI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight; out aTotalCost: TCost;
             out aArcFlows: TEdgeArray): TMcfState;
  {  }
    function IsMcfFeasible(const aSource, aSink: TVertex; const aArcFlows: TEdgeArray; aFlow: TWeight;
             aTotalCost: TCost): Boolean; inline;
    function IsMcfFeasibleI(aSrcIdx, aSinkIdx: SizeInt; const aArcFlows: TEdgeArray; aFlow: TWeight;
             aTotalCost: TCost): Boolean;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGSimpleDigraph.TReachabilityMatrix }

function TGSimpleDigraph.TReachabilityMatrix.GetSize: SizeInt;
begin
  Result := FMatrix.Size;
end;

procedure TGSimpleDigraph.TReachabilityMatrix.Clear;
begin
  if FMatrix.Size > 0 then
    begin
      FMatrix.Clear;
      FIds := nil;
    end;
end;

constructor TGSimpleDigraph.TReachabilityMatrix.Create(const aMatrix: TSquareBitMatrix; const aIds: TIntArray);
begin
  FMatrix := aMatrix;
  FIds := aIds;
end;

function TGSimpleDigraph.TReachabilityMatrix.IsEmpty: Boolean;
begin
  Result := FMatrix.Size = 0;
end;

function TGSimpleDigraph.TReachabilityMatrix.Reachable(aSrc, aDst: SizeInt): Boolean;
begin
  Result := FMatrix[FIds[aSrc], FIds[aDst]];
end;

{ TGSimpleDigraph.THamiltonSearch.TAdjList }

constructor TGSimpleDigraph.THamiltonSearch.TAdjList.Create(aDegree, aVertexCount: SizeInt; aAdjList: PAdjList);
var
  p: PAdjItem;
begin
  InDegree := aDegree;
  OutList.Capacity := aVertexCount;
  for p in aAdjList^ do
    OutList.UncBits[p^.Key] := True;
end;

{ TGSimpleDigraph.THamiltonSearch }

procedure TGSimpleDigraph.THamiltonSearch.Init(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector);
var
  I: SizeInt;
begin
  FSource := aSrc;
  if aCount <= 0 then
    FRequired := High(SizeInt)
  else
    FRequired := aCount;
  FPaths := pv;
  FNodeCount := aGraph.VertexCount;
  FStack := TSimpleStack.Create(Succ(FNodeCount));
  System.SetLength(FMatrix, FNodeCount);
  for I := 0 to Pred(FNodeCount) do
    FMatrix[I] := TAdjList.Create(aGraph.FNodeList[I].Tag, FNodeCount, @aGraph.FNodeList[I].AdjList);
  FVacant.InitRange(FNodeCount);
  FTimeOut := aTimeOut and System.High(Integer);
  FFound := 0;
  FDone := False;
  FCancelled := False;
  FStartTime := Now;
end;

function TGSimpleDigraph.THamiltonSearch.TimeToFinish: Boolean;
begin
  FCancelled := FCancelled or (SecondsBetween(Now, FStartTime) >= FTimeOut);
  Result := FCancelled or FDone;
end;

function TGSimpleDigraph.THamiltonSearch.SelectMin(const v: TBoolVector; out aValue: SizeInt): Boolean;
var
  I, Degree, MinDegree: SizeInt;
begin
  MinDegree := FNodeCount;
  aValue := NULL_INDEX;
  for I in v do
    begin
      Degree := FMatrix[I].OutList.PopCount;
      if Degree < MinDegree then
        begin
          MinDegree := Degree;
          aValue := I;
        end;
    end;
  Result := aValue <> NULL_INDEX;
end;

procedure TGSimpleDigraph.THamiltonSearch.CheckIsCycle(aNode: SizeInt);
begin
  if FMatrix[aNode].OutList.UncBits[FSource] then
    begin
      FStack.Push(FSource);
      FPaths^.Add(FStack.ToArray);
      Inc(FFound);
      FStack.Pop;
      FDone := FDone or (FFound >= FRequired);
    end;
end;

procedure TGSimpleDigraph.THamiltonSearch.CheckIsPath(aNode: SizeInt);
begin
  Assert(aNode = aNode); //to supress hints
  FPaths^.Add(FStack.ToArray);
  Inc(FFound);
  FDone := FDone or (FFound >= FRequired);
end;

procedure TGSimpleDigraph.THamiltonSearch.SearchFor(aNode: SizeInt);
var
  Cand, Saved: TBoolVector;
  I: SizeInt;
begin
  if FVacant.NonEmpty then
    begin
      for I in FVacant do
        if (FMatrix[I].InDegree = 0) or FMatrix[I].OutList.IsEmpty then
          exit;
      if FMatrix[aNode].OutList.IntersectionPop(FVacant) > 0 then
        begin
          Cand := FMatrix[aNode].OutList.Intersection(FVacant);
          Saved.Capacity := FNodeCount;
          for I in Cand do
            begin
              Saved.UncBits[I] := FMatrix[I].OutList.UncBits[aNode];
              FMatrix[I].OutList.UncBits[aNode] := False;
              Dec(FMatrix[I].InDegree, Ord(Saved.UncBits[I]));
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
            begin
              FMatrix[I].OutList.UncBits[aNode] := True;
              Inc(FMatrix[I].InDegree);
            end;
        end;
    end
  else
    FCheckNode(aNode);
end;

procedure TGSimpleDigraph.THamiltonSearch.ExecuteCycles;
var
  I: SizeInt;
begin
  FVacant.UncBits[FSource] := False;
  FStack.Push(FSource);
  FCheckNode := @CheckIsCycle;
  for I in FMatrix[FSource].OutList do
    begin
      FStack.Push(I);
      FVacant.UncBits[I] := False;
      SearchFor(I);
      if TimeToFinish then
        break;
      FVacant.UncBits[I] := True;
      FStack.Pop;
      FMatrix[I].OutList.UncBits[FSource] := False;
    end;
end;

procedure TGSimpleDigraph.THamiltonSearch.ExecutePaths;
var
  I: SizeInt;
begin
  FVacant.UncBits[FSource] := False;
  FStack.Push(FSource);
  FCheckNode := @CheckIsPath;
  for I in FMatrix[FSource].OutList do
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

function TGSimpleDigraph.THamiltonSearch.FindCycles(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector): Boolean;
begin
  Init(aGraph, aSrc, aCount, aTimeOut, pv);
  ExecuteCycles;
  Result := not FCancelled and pv^.NonEmpty;
end;

function TGSimpleDigraph.THamiltonSearch.FindPaths(aGraph: TGSimpleDigraph; aSrc, aCount: SizeInt; aTimeOut: Integer;
  pv: PIntArrayVector): Boolean;
begin
  Init(aGraph, aSrc, aCount, aTimeOut, pv);
  ExecutePaths;
  Result := not FCancelled and pv^.NonEmpty;
end;

{ TGSimpleDigraph.TIncomingEnumerator }

function TGSimpleDigraph.TIncomingEnumerator.GetCurrent: TIncomingArc;
begin
  Result := FCurrArc;
end;

function TGSimpleDigraph.TIncomingEnumerator.MoveNext: Boolean;
var
  p: PAdjItem;
begin
  repeat
    if (FInCount < 1) or (FCurrIndex >= FLastIndex) then
      exit(False);
    Inc(FCurrIndex);
    p := FGraph.AdjLists[FCurrIndex]^.Find(FTarget);
    if p <> nil then
      begin
        FCurrArc.Source := FCurrIndex;
        FCurrArc.Data := p^.Data;
        Dec(FInCount);
        exit(True);
      end;
  until False;
end;

{ TGSimpleDigraph.TIncomingArcs }

function TGSimpleDigraph.TIncomingArcs.GetEnumerator: TIncomingEnumerator;
begin
  Result.FGraph := FGraph;
  Result.FTarget := FTarget;
  Result.FCurrIndex := NULL_INDEX;
  Result.FLastIndex := Pred(FGraph.VertexCount);
  Result.FInCount := FGraph.FNodeList[FTarget].Tag;
end;

{ TGSimpleDigraph.TDomTree.TDomSetEnumerator }

function TGSimpleDigraph.TDomTree.TDomSetEnumerator.MoveNext: Boolean;
begin
  Result := FTree[FCurr] >= 0;
  if Result then
    FCurr := FTree[FCurr];
end;

{ TGSimpleDigraph.TDomTree.TDominatedEnumerator }

function TGSimpleDigraph.TDomTree.TDominatedEnumerator.MoveNext: Boolean;
var
  Next: SizeInt;
begin
  Result := FNodeList[FCurr].Next >= 0;
  if Result then
    begin
      Next := FNodeList[FCurr].Next;
      if FNodeList[Next].OutTime > FRootTime then
        exit(False);
      FCurr := Next;
    end;
end;

{ TGSimpleDigraph.TDomTree.TDomSet }

function TGSimpleDigraph.TDomTree.TDomSet.GetEnumerator: TDomSetEnumerator;
begin
  Result.FTree := FTree;
  Result.FCurr := FIndex;
end;

{ TGSimpleDigraph.TDomTree.TDominated }

function TGSimpleDigraph.TDomTree.TDominated.GetEnumerator: TDominatedEnumerator;
begin
  Result.FNodeList := FNodeList;
  Result.FCurr := FIndex;
  Result.FRootTime := FNodeList[FIndex].OutTime;
end;

{ TGSimpleDigraph.TDomTree }

function TGSimpleDigraph.TDomTree.GetCount: SizeInt;
begin
  Result := System.Length(FNodeList);
end;

procedure TGSimpleDigraph.TDomTree.Dfs;
var
  TmpTree: TIntSetArray = nil;
  AdjEnums: array of TIntSet.TEnumerator = nil;
  Stack: TIntArray = nil;
  Curr, Prev, Next, sTop, Counter: SizeInt;
begin
  System.SetLength(TmpTree, FTree.Length);
  for Curr := 0 to System.High(TmpTree) do
    begin
      Prev := FTree[Curr];
      if Prev >= 0 then
        TmpTree[Prev].Push(Curr);
    end;
  System.SetLength(AdjEnums, System.Length(TmpTree));
  for Curr := 0 to System.High(TmpTree) do
    AdjEnums[Curr] := TmpTree[Curr].GetEnumerator;
  Counter := 1;
  FSize := 1;
  sTop := 0;
  Stack.Length := FTree.Length;
  Stack[0] := FRoot;
  FNodeList[FRoot].InTime := 0;
  Prev := FRoot;
  while sTop >= 0 do
    begin
      Curr := Stack[sTop];
      if AdjEnums[Curr].MoveNext then
        begin
          Next := AdjEnums[Curr].Current;
          if FNodeList[Next].InTime = NULL_INDEX then
            begin
              FNodeList[Next].InTime := Counter;
              FNodeList[Prev].Next := Next;
              Prev := Next;
              Inc(sTop);
              Stack[sTop] := Next;
              Inc(Counter);
              Inc(FSize);
            end;
        end
      else
        begin
          FNodeList[Curr].OutTime := Counter;
          Dec(sTop);
          Inc(Counter);
        end;
    end;
end;

function TGSimpleDigraph.TDomTree.GetIDom(aIndex: SizeInt): SizeInt;
begin
  if SizeUInt(aIndex) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aIndex]);
  Result := FTree[aIndex];
end;

procedure TGSimpleDigraph.TDomTree.Init(const aTree: TIntArray; aRoot: SizeInt);
begin
  FTree := aTree;
  FRoot := aRoot;
  System.SetLength(FNodeList, FTree.Length);
  System.FillChar(Pointer(FNodeList)^, SizeOf(TNode) * System.Length(FNodeList), $ff);
  Dfs;
end;

function TGSimpleDigraph.TDomTree.Dominates(aLeft, aRight: SizeInt): Boolean;
begin
  if SizeUInt(aLeft) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aLeft]);
  if SizeUInt(aRight) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aRight]);
  if aLeft <> aRight then
    Result := (FNodeList[aLeft].InTime < FNodeList[aRight].InTime) and
              (FNodeList[aLeft].OutTime > FNodeList[aRight].OutTime)
  else
    Result := True;
end;

function TGSimpleDigraph.TDomTree.DomSetOf(aValue: SizeInt): TDomSet;
begin
  if SizeUInt(aValue) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aValue]);
  Result.FTree := FTree;
  Result.FIndex := aValue;
end;

function TGSimpleDigraph.TDomTree.ExtractDomSet(aValue: SizeInt): TIntArray;
var
  I, Curr: SizeInt;
begin
  Result := nil;
  if SizeUInt(aValue) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aValue]);
  Result.Length := INIT_LEN;
  Curr := FTree[aValue];
  I := 0;
  while Curr >= 0 do
    begin
      if Result.Length = I then
        Result.Length := I shl 1;
      Result[I] := Curr;
      Curr := FTree[Curr];
      Inc(I);
    end;
  Result.Length := I;
end;

function TGSimpleDigraph.TDomTree.DominatedBy(aValue: SizeInt): TDominated;
begin
  if SizeUInt(aValue) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aValue]);
  Result.FNodeList := FNodeList;
  Result.FIndex := aValue;
end;

function TGSimpleDigraph.TDomTree.ExtractDominated(aValue: SizeInt): TIntArray;
var
  I, Next, RootTime: SizeInt;
begin
  Result := nil;
  if SizeUInt(aValue) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aValue]);
  I := 0;
  Result.Length := INIT_LEN;
  RootTime := FNodeList[aValue].OutTime;
  while FNodeList[aValue].Next >= 0 do
    begin
      Next := FNodeList[aValue].Next;
      if FNodeList[Next].OutTime > RootTime then
        break;
      if Result.Length = I then
        Result.Length := I shl 1;
      Result[I] := Next;
      aValue := Next;
      Inc(I);
    end;
  Result.Length := I;
end;

function TGSimpleDigraph.TDomTree.NcDom(aLeft, aRight: SizeInt): SizeInt;
begin
  if SizeUInt(aLeft) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aLeft]);
  if SizeUInt(aRight) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aRight]);
  if aLeft = aRight then
    exit(aLeft);
  if (FNodeList[aLeft].InTime >= 0) and (FNodeList[aRight].InTime >= 0) then
    begin
      while FNodeList[aLeft].InTime <> FNodeList[aRight].InTime do
        begin
          while FNodeList[aLeft].InTime > FNodeList[aRight].InTime do
            aLeft := FTree[aLeft];
          while FNodeList[aRight].InTime > FNodeList[aLeft].InTime do
            aRight := FTree[aRight];
        end;
      Result := aLeft;
    end
  else
    Result := NULL_INDEX;
end;

function TGSimpleDigraph.TDomTree.InTree(aValue: SizeInt): Boolean;
begin
  if SizeUInt(aValue) >= SizeUInt(Count) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [SDomTree, aValue]);
  Result := FNodeList[aValue].InTime >= 0;
end;

{ TGSimpleDigraph }

function TGSimpleDigraph.GetDensity: Double;
begin
  if NonEmpty then
    Result := Double(EdgeCount)/(Double(VertexCount) * Double(Pred(VertexCount)))
  else
    Result := 0.0;
end;

function TGSimpleDigraph.GetReachabilityValid: Boolean;
begin
  Result := NonEmpty and not FReachabilityMatrix.IsEmpty;
end;

function TGSimpleDigraph.CreateSkeleton: TSkeleton;
var
  I: SizeInt;
begin
  Result := TSkeleton.Create(VertexCount, True);
  Result.FEdgeCount := EdgeCount;
  for I := 0 to Pred(VertexCount) do
    Result[I]^.AssignList(AdjLists[I]);
end;

procedure TGSimpleDigraph.AssignGraph(aGraph: TGSimpleDigraph);
var
  I: SizeInt;
begin
  Clear;
  FCount := aGraph.VertexCount;
  FEdgeCount := aGraph.EdgeCount;
  FTitle := aGraph.Title;
  FDescription := aGraph.Description;
  if aGraph.NonEmpty then
    begin
      FChainList := System.Copy(aGraph.FChainList);
      System.SetLength(FNodeList, System.Length(aGraph.FNodeList));
      for I := 0 to Pred(VertexCount) do
        FNodeList[I].Assign(aGraph.FNodeList[I]);
    end;
  if not aGraph.FReachabilityMatrix.IsEmpty then
    begin
      FReachabilityMatrix.FMatrix.FSize := aGraph.FReachabilityMatrix.FMatrix.FSize;
      FReachabilityMatrix.FMatrix.FBits := System.Copy(aGraph.FReachabilityMatrix.FMatrix.FBits);
      FReachabilityMatrix.FIds := System.Copy(aGraph.FReachabilityMatrix.FIds);
    end;
end;

procedure TGSimpleDigraph.AssignReverse(aGraph: TGSimpleDigraph);
var
  I: SizeInt;
  p: PAdjItem;
begin
  Clear;
  EnsureCapacity(aGraph.VertexCount);
  Title := aGraph.Title;
  Description := aGraph.Description;
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      AddVertex(aGraph.FNodeList[I].Vertex);
      FNodeList[I].AdjList.EnsureCapacity(aGraph.FNodeList[I].Tag);
    end;
  for I := 0 to Pred(aGraph.VertexCount) do
    for p in aGraph.AdjLists[I]^ do
      DoAddEdge(p^.Destination, I, p^.Data);
end;

function TGSimpleDigraph.FindCycle(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Visited, InStack: TBoolVector;
  Parents: TIntArray;
  Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Parents := CreateIntArray;
  InStack.Capacity := VertexCount;
  Visited.Capacity := VertexCount;
  Stack.Push(aRoot);
  InStack.UncBits[aRoot] := True;
  Visited.UncBits[aRoot] := True;
  while Stack.TryPeek(aRoot) do
    if AdjEnums[aRoot].MoveNext then
      begin
        Next := AdjEnums[aRoot].Current;
        if not Visited.UncBits[Next] then
          begin
            Parents[Next] := aRoot;
            InStack.UncBits[Next] := True;
            Visited.UncBits[Next] := True;
            Stack.Push(Next);
          end
        else
          if InStack.UncBits[Next] then
            begin
              aCycle := TreeExtractCycle(Parents, Next, aRoot);
              exit(True);
            end;
      end
    else
      InStack.UncBits[Stack.Pop{%H-}] := False;
  Result := False;
end;

function TGSimpleDigraph.CycleExists: Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Visited, InStack: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  InStack.Capacity := VertexCount;
  Visited.Capacity := VertexCount;
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Stack.Push(I);
        Visited.UncBits[I] := True;
        InStack.UncBits[I] := True;
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  InStack.UncBits[Next] := True;
                  Stack.Push(Next);
                end
              else
                if InStack.UncBits[Next] then
                  exit(True);
            end
          else
            InStack.UncBits[Stack.Pop{%H-}] := False;
      end;
  Result := False;
end;

function TGSimpleDigraph.GetDomTree(aSrc: SizeInt; out aSize: SizeInt; out aPreds: TIntSetArray): TIntArray;
var
  Parents, PostOrd, Idx2Ord, Doms: TIntArray;
  Counter: SizeInt absolute aSize;

  procedure OnWhite(aNode, aParent: SizeInt);
  begin
    Parents[aNode] := aParent;
    if aNode <> aSrc then
      aPreds[aNode].Push(aParent);
  end;

  procedure OnGray(aNode, aParent: SizeInt);
  begin
    if aNode <> aSrc then
      aPreds[aNode].Push(aParent);
  end;

  procedure OnDone(aIndex: SizeInt);
  begin
    PostOrd[Counter] := aIndex;
    Inc(Counter);
  end;

  function Nca(aLeft, aRight: SizeInt): SizeInt;
  begin
    while aLeft <> aRight do
      begin
        while aLeft < aRight do
          aLeft := Doms[aLeft];
        while aRight < aLeft do
          aRight := Doms[aRight];
      end;
    Result := aLeft;
  end;

var
  I, J, IDom, Prev: SizeInt;
  Ready: Boolean;
begin
  aPreds := nil;
  Counter := 0;
  Parents := CreateIntArray;
  PostOrd := CreateIntArray;
  System.SetLength(aPreds, VertexCount);
  DfsTraversalI(aSrc, @OnWhite, @OnGray, @OnDone);
  Idx2Ord := CreateIntArray;
  for I := 0 to Pred(Counter) do
    Idx2Ord[PostOrd[I]] := I;
  Doms := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    begin
      J := Parents[I];
      if J <> NULL_INDEX then
        Doms[Idx2Ord[I]] := Idx2Ord[J];
    end;
  Doms[Pred(Counter)] := Pred(Counter);
  repeat
    Ready := True;
    for I := Counter - 2 downto 0 do
      if Doms[I] <> 0 then
        begin
          IDom := 0;
          for J in aPreds[PostOrd[I]] do
            begin
              Prev := Idx2Ord[J];
              if IDom <> 0 then
                IDom := Nca(Prev, IDom)
              else
                IDom := Prev;
            end;
          if Doms[I] <> IDom then
            begin
              Doms[I] := IDom;
              Ready := False;
            end;
        end;
  until Ready;
  for I := 0 to Counter - 2 do
    Parents[PostOrd[I]] := PostOrd[Doms[I]];
  Parents[aSrc] := aSrc;
  Result := Parents;
end;

function TGSimpleDigraph.GetDomTreeSnca(aSrc: SizeInt; out aSize: SizeInt; out aPreds: TIntSetArray; out
  aOrd2Idx, aIdx2Ord: TIntArray): TIntArray;
var
  Parents: TIntArray;
  Counter: SizeInt absolute aSize;

  procedure Dfs(From: SizeInt);
  var
    Stack: TIntArray;
    AdjEnums: TAdjEnumArray;
    Next, sTop: SizeInt;
  begin
    AdjEnums := CreateAdjEnumArray;
    aIdx2Ord[From] := 0;
    Counter := 1;
    {%H-}Stack.Length := VertexCount;
    sTop := 0;
    Stack[sTop] := From;
    while sTop >= 0 do
      begin
        From := Stack[sTop];
        if AdjEnums[From].MoveNext then
          begin
            Next := AdjEnums[From].Current;
            if aIdx2Ord[Next] = NULL_INDEX then
              begin
                aIdx2Ord[Next] := Counter;
                Parents[Counter] := aIdx2Ord[From];
                Inc(sTop);
                Inc(Counter);
                Stack[sTop] := Next;
              end;
            if Next <> aSrc then
              aPreds[aIdx2Ord[Next]].Push(aIdx2Ord[From]);
          end
        else
          Dec(sTop);
      end
  end;

var
  Labels, SemiDoms, IDoms: TIntArray;

  procedure Compress(aLeft, aRight: SizeInt);
  var
    Node: SizeInt;
  begin
    Node := Parents[aLeft];
    if Node > aRight then
      begin
        Compress(Node, aRight);
        if Labels[Node] < Labels[aLeft] then
          Labels[aLeft] := Labels[Node];
        Parents[aLeft] := Parents[Node];
      end;
  end;

var
  I, Prev, Dom: SizeInt;
begin
  aPreds := nil;
  aIdx2Ord := nil;
  aOrd2Idx := nil;
  aIdx2Ord := CreateIntArray;
  Parents := CreateIntArray;
  System.SetLength(aPreds, VertexCount);
  Dfs(aSrc);
  aOrd2Idx := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if aIdx2Ord[I] <> NULL_INDEX then
      aOrd2Idx[aIdx2Ord[I]] := I;
  Labels := CreateIntArrayRange;
  SemiDoms := Labels.Copy;
  Parents[0] := 0;
  IDoms := Parents.Copy;
  for I := Pred(Counter) downto 1 do
    begin
      for Prev in aPreds[I] do
        begin
          if Prev < I then
            Dom := Prev
          else
            begin
              Compress(Prev, I);
              Dom := Labels[Prev];
            end;
          if SemiDoms[Dom] < SemiDoms[I] then
            SemiDoms[I] := SemiDoms[Dom];
        end;
      Labels[I] := SemiDoms[I];
    end;
  Parents.Fill(NULL_INDEX);
  for I := 1 to Pred(Counter) do
    begin
      Dom := IDoms[I];
      while Dom > SemiDoms[I] do
        Dom := IDoms[Dom];
      IDoms[I] := Dom;
      Parents[aOrd2Idx[I]] := aOrd2Idx[Dom];
    end;
  Parents[aSrc] := aSrc;
  Result := Parents;
end;

function TGSimpleDigraph.TestIsDomTree(const aTree: TIntArray; aSrc: SizeInt): Boolean;
var
  TestTree: TIntSetArray = nil;
  PreOrd: TIntArray = nil;
  SubTreeSize: TIntArray = nil;
  Visited: TBoolVector;
  Counter: SizeInt = 0;

  function IsRootedTree: Boolean;
  var
    Parents: TIntArray;

    procedure Dfs(aNode: SizeInt);
    var
      Next: SizeInt;
    begin
      for Next in TestTree[aNode] do
        if PreOrd[Next] = NULL_INDEX then
          begin
            Visited.UncBits[Next] := True;
            Parents[Next] := aNode;
            SubTreeSize[Next] := 1;
            PreOrd[Next] := Counter;
            Inc(Counter);
            Dfs(Next);
          end;
      if Parents[aNode] <> NULL_INDEX then
        SubTreeSize[Parents[aNode]] += SubTreeSize[aNode];
    end;

  var
    I, Prev: SizeInt;
    TreeSize: SizeInt = 1;
  begin
    System.SetLength(TestTree, VertexCount);
    for I := 0 to Pred(VertexCount) do
      begin
        Prev := aTree[I];
        if Prev >= 0 then
          begin
            if (Prev >= VertexCount) or (Prev = I) then
              exit(False);
            TestTree[Prev].Push(I);
            Inc(TreeSize);
          end;
      end;
    PreOrd := CreateIntArray;
    SubTreeSize := CreateIntArray(0);
    Parents := CreateIntArray;
    Visited.Capacity := VertexCount;
    SubTreeSize[aSrc] := 1;
    Visited.UncBits[aSrc] := True;
    PreOrd[aSrc] := Counter;
    Inc(Counter);
    Dfs(aSrc);
    Result := SubTreeSize[aSrc] = TreeSize;
  end;

var
  DfsMatchTree: Boolean = True;
  HasParentProp: Boolean = True;

  procedure OnWhite(aNode, aParent: SizeInt);
  var
    Dom: SizeInt;
  begin
    DfsMatchTree := DfsMatchTree and Visited.UncBits[aNode];
    if aNode <> aSrc then
      begin
        Dom := aTree[aNode];
        HasParentProp := HasParentProp and ((PreOrd[Dom] <= PreOrd[aParent]) and
                        (PreOrd[aParent] < PreOrd[Dom] + SubTreeSize[Dom]));
      end;
  end;

  procedure OnGray(aNode, aParent: SizeInt);
  var
    Dom: SizeInt;
  begin
    if aNode <> aSrc then
      begin
        Dom := aTree[aNode];
        HasParentProp := HasParentProp and ((PreOrd[Dom] <= PreOrd[aParent]) and
                        (PreOrd[aParent] < PreOrd[Dom] + SubTreeSize[Dom]));
      end;
  end;

begin
  if not IsRootedTree() then
    exit(False);
  if DfsTraversalI(aSrc, @OnWhite, @OnGray, nil) <> SubTreeSize[aSrc] then
    exit(False);
  Result := DfsMatchTree and HasParentProp;
end;

function TGSimpleDigraph.TopoSort: TIntArray;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Visited: TBoolVector;
  Counter, I, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Result := CreateIntArray;
  Visited.Capacity := VertexCount;
  Counter := Pred(VertexCount);
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Visited.UncBits[I] := True;
        Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  Stack.Push(Next);
                end;
            end
          else
            begin
              Result[Counter] := Stack.Pop;
              Dec(Counter);
            end;
      end;
end;

function TGSimpleDigraph.TopoSort(out a: TIntArray): Boolean;
var
  Stack: TSimpleStack;
  Visited, InStack: TBoolVector;
  Parents: TIntArray;
  AdjEnums: TAdjEnumArray;
  Counter, I, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  a.Length := VertexCount;
  Parents := CreateIntArray;
  InStack.Capacity := VertexCount;
  Visited.Capacity := VertexCount;
  Counter := Pred(VertexCount);
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Stack.Push(I);
        InStack.UncBits[I] := True;
        Visited.UncBits[I] := True;
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Stack.Push(Next);
                  Parents[Next] := Curr;
                  InStack.UncBits[Next] := True;
                  Visited.UncBits[Next] := True;
                end
              else
                if InStack[Next] then
                  begin
                    a := TreeExtractCycle(Parents, Next, Curr);
                    exit(False);
                  end;
            end
          else
            begin
              Next := Stack.Pop;
              a[Counter] := Next;
              InStack[Next] := False;
              Dec(Counter);
            end;
      end;
  Result := True;
end;

function TGSimpleDigraph.GetDagLongestPaths(aSrc: SizeInt): TIntArray;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Visited: TBoolVector;
  d, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Result := CreateIntArray;
  Visited.Capacity := VertexCount;
  Visited.UncBits[aSrc] := True;
  Result[aSrc] := 0;
  Stack.Push(aSrc);
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if not Visited.UncBits[Next] then
          begin
            Visited.UncBits[Next] := True;
            d := Succ(Result[Curr]);
            if d > Result[Next] then
              Result[Next] := d;
            Stack.Push(Next);
          end;
      end
    else
      Stack.Pop;
end;

function TGSimpleDigraph.GetDagLongestPaths(aSrc: SizeInt; out aTree: TIntArray): TIntArray;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Visited: TBoolVector;
  d, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Result := CreateIntArray;
  aTree := CreateIntArray;
  Visited.Capacity := VertexCount;
  Visited.UncBits[aSrc] := True;
  Result[aSrc] := 0;
  {%H-}Stack.Push(aSrc);
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if not Visited.UncBits[Next] then
          begin
            Visited.UncBits[Next] := True;
            d := Succ(Result[Curr]);
            if d > Result[Next] then
              begin
                Result[Next] := d;
                aTree[Next] := Curr;
              end;
            Stack.Push(Next);
          end;
      end
    else
      Stack.Pop;
end;

function TGSimpleDigraph.SearchForStrongComponents(out aIds: TIntArray): SizeInt;
var
  Stack, VtxStack, PathStack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  PreOrd: TIntArray;
  I, Counter, Curr, Next: SizeInt;
begin
  Stack := TSimpleStack.Create(VertexCount);
  VtxStack := TSimpleStack.Create(VertexCount);
  PathStack := TSimpleStack.Create(VertexCount);
  PreOrd := CreateIntArray;
  aIds := CreateIntArray;
  AdjEnums := CreateAdjEnumArray;
  Counter := 0;
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = NULL_INDEX then
      begin
        PreOrd[I] := Counter;
        Inc(Counter);
        Stack.Push(I);
        VtxStack.Push(I);
        PathStack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if PreOrd[Next] = NULL_INDEX then
                begin
                  PreOrd[Next] := Counter;
                  Inc(Counter);
                  Stack.Push(Next);
                  VtxStack.Push(Next);
                  PathStack.Push(Next);
                end
              else
                if aIds[Next] = NULL_INDEX then
                  while PreOrd[PathStack.Peek] > PreOrd[Next] do
                    PathStack.Pop;
            end
          else
            begin
              Curr := Stack.Pop;
              if PathStack.Peek = Curr then
                begin
                  PathStack.Pop;
                  repeat
                    Next := VtxStack.Pop;
                    aIds[Next] := Result;
                  until Next = Curr;
                  Inc(Result);
                end;
            end;
      end;
end;

function TGSimpleDigraph.GetReachabilityMatrix(const aScIds: TIntArray; aScCount: SizeInt): TReachabilityMatrix;
var
  Stack: TSimpleStack;
  Visited, IdVisited: TBoolVector;
  IdParents, IdOrd: TIntArray;
  m: TSquareBitMatrix;
  Pairs: TIntPairSet;
  AdjEnums: TAdjEnumArray;
  I, J, Counter, Curr, Next, CurrId, NextId: SizeInt;
begin
  if aScCount = 1 then
    begin
      m := TSquareBitMatrix.Create(aScCount);
      m[0, 0] := True;
      exit(TReachabilityMatrix.Create(m, aScIds));
    end;
  Stack := TSimpleStack.Create(VertexCount);
  IdParents := CreateIntArray(aScCount, NULL_INDEX);
  IdOrd := CreateIntArray(aScCount, NULL_INDEX);
  Visited.Capacity := VertexCount;
  IdVisited.Capacity := aScCount;
  AdjEnums := CreateAdjEnumArray;
  Counter := 0;
  m := TSquareBitMatrix.Create(aScCount);
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Visited.UncBits[I] := True;
        Stack.Push(I);
        if IdOrd[aScIds[I]] = NULL_INDEX then
          begin
            IdOrd[aScIds[I]] := Counter;
            Inc(Counter);
          end;
        while Stack.TryPeek(Curr) do
          begin
            CurrId := aScIds[{%H-}Curr];
            if AdjEnums[{%H-}Curr].MoveNext then
              begin
                Next := AdjEnums[Curr].Current;
                NextId := aScIds[Next];
                m[CurrId, NextId] := True;
                if IdOrd[CurrId] < IdOrd[NextId] then
                  continue;
                if not Visited.UncBits[Next] then
                  begin
                    Visited.UncBits[Next] := True;
                    Stack.Push(Next);
                    if IdOrd[NextId] = NULL_INDEX then
                      begin
                        IdOrd[NextId] := Counter;
                        IdParents[NextId] := CurrId;
                        Inc(Counter);
                      end
                  end
                    else
                      if Pairs.Add(IdOrd[CurrId], IdOrd[NextId]) then
                        for J := 0 to Pred(aScCount) do
                          if m[NextId, J] then
                            m[CurrId, J] := True;
              end
            else
              begin
                Next := aScIds[Stack.Pop];
                if not IdVisited.UncBits[Next] then
                  begin
                    IdVisited.UncBits[Next] := True;
                    Curr := IdParents[Next];
                    if Curr <> -1 then
                      for J := 0 to Pred(aScCount) do
                        if m[Next, J] then
                          m[Curr, J] := True;
                  end;
              end;
          end;
      end;
  Result := TReachabilityMatrix.Create(m, aScIds);
end;

function TGSimpleDigraph.DoAddVertex(const aVertex: TVertex; out aIndex: SizeInt): Boolean;
begin
  Result := not FindOrAdd(aVertex, aIndex);
  if Result then
    begin
      FNodeList[aIndex].Tag := 0;
      FReachabilityMatrix.Clear;
    end;
end;

procedure TGSimpleDigraph.DoRemoveVertex(aIndex: SizeInt);
var
  I, J: SizeInt;
  p: ^TAdjItem;
  CurrEdges: TAdjList.TAdjItemArray;
begin
  FEdgeCount -= FNodeList[aIndex].AdjList.Count;
  for p in FNodeList[aIndex].AdjList do
    Dec(FNodeList[p^.Destination].Tag);
  Delete(aIndex);
  for I := 0 to Pred(VertexCount) do
    begin
      CurrEdges := FNodeList[I].AdjList.ToArray;
      FNodeList[I].AdjList.MakeEmpty;
      for J := 0 to System.High(CurrEdges) do
        begin
          if CurrEdges[J].Destination <> aIndex then
            begin
              if CurrEdges[J].Destination > aIndex then
                Dec(CurrEdges[J].Destination);
              FNodeList[I].AdjList.Add(CurrEdges[J]);
            end;
        end;
    end;
  FReachabilityMatrix.Clear;
end;

function TGSimpleDigraph.DoAddEdge(aSrc, aDst: SizeInt; const aData: TEdgeData): Boolean;
begin
  Result := not (aSrc = aDst) and FNodeList[aSrc].AdjList.Add(TAdjItem.Create(aDst, aData));
  if Result then
    begin
      Inc(FNodeList[aDst].Tag);
      Inc(FEdgeCount);
      FReachabilityMatrix.Clear;
    end;
end;

function TGSimpleDigraph.DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
begin
  Result := not (aSrc = aDst) and FNodeList[aSrc].AdjList.Remove(aDst);
  if Result then
    begin
      Dec(FNodeList[aDst].Tag);
      Dec(FEdgeCount);
      FReachabilityMatrix.Clear;
    end;
end;

function TGSimpleDigraph.DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeData): Boolean;
var
  p: PAdjItem;
begin
  p := AdjLists[aSrc]^.Find(aDst);
  Result := p <> nil;
  if Result then
    p^.Data := aValue;
end;

procedure TGSimpleDigraph.DoWriteEdges(aStream: TStream; aOnWriteData: TOnWriteData);
var
  s, d: Integer;
  e: TEdge;
begin
  for e in Edges do
    begin
      s := e.Source;
      d := e.Destination;
      aStream.WriteBuffer(NtoLE(s), SizeOf(s));
      aStream.WriteBuffer(NtoLE(d), SizeOf(d));
      aOnWriteData(aStream, e.Data);
    end;
end;

procedure TGSimpleDigraph.EdgeContracting(aSrc, aDst: SizeInt);
var
  ToRemove: TIntArray = nil;
  a: TIncomingArc;
  I, RemoveCount: SizeInt;
  p: PAdjItem;
begin
  //there arc aSrc -> aDst already removed
  if AdjLists[aDst]^.Count <> 0 then
    begin
      ToRemove.Length := AdjLists[aDst]^.Count;
      RemoveCount := 0;
      for p in AdjLists[aDst]^ do
        if not DoAddEdge(aSrc, p^.Destination, p^.Data) then
          begin
            ToRemove[RemoveCount] := p^.Destination;
            Inc(RemoveCount);
          end;
      for I := 0 to Pred(RemoveCount) do
        DoRemoveEdge(aDst, ToRemove[I]);
      Dec(FEdgeCount, AdjLists[aDst]^.Count);
      AdjLists[aDst]^.MakeEmpty;
    end;
  for a in IncomingArcsI(aDst) do
    if DoAddEdge(a.Source, aSrc, a.Data) then
      begin
        AdjLists[a.Source]^.Remove(aDst);
        Dec(FEdgeCount);
      end
    else
      DoRemoveEdge(a.Source, aDst);
end;

procedure TGSimpleDigraph.Clear;
begin
  inherited;
  FReachabilityMatrix.Clear;
end;

function TGSimpleDigraph.Clone: TGSimpleDigraph;
begin
  Result := TGSimpleDigraph.Create;
  Result.AssignGraph(Self);
end;

function TGSimpleDigraph.Reverse: TGSimpleDigraph;
begin
  Result := TGSimpleDigraph.Create;
  Result.AssignReverse(Self);
end;

function TGSimpleDigraph.InducedSubgraph(const aVertexList: TIntArray): TGSimpleDigraph;
begin
  Result := TGSimpleDigraph.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

procedure TGSimpleDigraph.SetSymmDifferenceOf(aGraph: TGSimpleDigraph);
var
  Tmp: TGSimpleDigraph;
  e: TEdge;
  s, d: TVertex;
begin
  Tmp := TGSimpleDigraph.Create;
  try
    Tmp.Title := Title;
    Tmp.Description := Description;
    for e in Edges do
      begin
        s := Items[e.Source];
        d := Items[e.Destination];
        if not aGraph.ContainsEdge(s, d) then
          Tmp.AddEdge(s, d, e.Data);
      end;
    for e in aGraph.Edges do
      begin
        s := aGraph[e.Source];
        d := aGraph[e.Destination];
        if not ContainsEdge(s, d) then
          Tmp.AddEdge(s, d, e.Data);
      end;
    AssignGraph(Tmp);
  finally
    Tmp.Free;
  end;
end;

function TGSimpleDigraph.InDegree(const aVertex: TVertex): SizeInt;
begin
  Result := InDegreeI(IndexOf(aVertex));
end;

function TGSimpleDigraph.InDegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].Tag;
end;

function TGSimpleDigraph.OutDegree(const aVertex: TVertex): SizeInt;
begin
  Result := OutDegreeI(IndexOf(aVertex));
end;

function TGSimpleDigraph.OutDegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].AdjList.Count;
end;

function TGSimpleDigraph.Degree(const aVertex: TVertex): SizeInt;
begin
  Result := DegreeI(IndexOf(aVertex));
end;

function TGSimpleDigraph.DegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].AdjList.Count + FNodeList[aIndex].Tag;
end;

function TGSimpleDigraph.Isolated(const aVertex: TVertex): Boolean;
begin
  Result := Degree(aVertex) = 0;
end;

function TGSimpleDigraph.IsolatedI(aIndex: SizeInt): Boolean;
begin
  Result := DegreeI(aIndex) = 0;
end;

function TGSimpleDigraph.IsSource(const aVertex: TVertex): Boolean;
begin
  Result := IsSourceI(IndexOf(aVertex));
end;

function TGSimpleDigraph.IsSourceI(aIndex: SizeInt): Boolean;
begin
  CheckIndexRange(aIndex);
  Result := (FNodeList[aIndex].AdjList.Count <> 0) and (FNodeList[aIndex].Tag = 0);
end;

function TGSimpleDigraph.IsSink(const aVertex: TVertex): Boolean;
begin
  Result := IsSinkI(IndexOf(aVertex));
end;

function TGSimpleDigraph.IsSinkI(aIndex: SizeInt): Boolean;
begin
  CheckIndexRange(aIndex);
  Result := (FNodeList[aIndex].AdjList.Count = 0) and (FNodeList[aIndex].Tag <> 0);
end;

function TGSimpleDigraph.SourceCount: SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    if (FNodeList[I].AdjList.Count <> 0) and (FNodeList[I].Tag = 0) then
      Inc(Result);
end;

function TGSimpleDigraph.SinkCount: SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    if (FNodeList[I].AdjList.Count = 0) and (FNodeList[I].Tag <> 0) then
      Inc(Result);
end;

function TGSimpleDigraph.IncomingArcs(const aVertex: TVertex): TIncomingArcs;
begin
  Result := IncomingArcsI(IndexOf(aVertex));
end;

function TGSimpleDigraph.IncomingArcsI(aIndex: SizeInt): TIncomingArcs;
begin
  CheckIndexRange(aIndex);
  Result.FGraph := Self;
  Result.FTarget := aIndex;
end;

function TGSimpleDigraph.PathExists(const aSrc, aDst: TVertex): Boolean;
begin
  Result := PathExistsI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleDigraph.PathExistsI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(True);
  if ReachabilityValid then
    exit(FReachabilityMatrix.Reachable(aSrc, aDst));
  Result := CheckPathExists(aSrc, aDst);
end;

function TGSimpleDigraph.ReachableFrom(const aSource: TVertex): TIntArray;
begin
  Result := ReachableFromI(IndexOf(aSource));
end;

function TGSimpleDigraph.ReachableFromI(aSrcIdx: SizeInt): TIntArray;
var
  Reachable: TIntArray = nil;
  Counter: SizeInt = 0;
  procedure OnWhite(aNode, aParent: SizeInt);
  begin
    Assert(aParent = aParent); // :))))
    Reachable[Counter] := aNode;
    Inc(Counter);
  end;
begin
  CheckIndexRange(aSrcIdx);
  Reachable.Length := VertexCount;
  BfsTraversalI(aSrcIdx, @OnWhite, nil, nil);
  Reachable.Length := Counter;
  Result := Reachable;
end;

function TGSimpleDigraph.ContainsCycle(const aSource: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsCycleI(IndexOf(aSource), aCycle);
end;

function TGSimpleDigraph.ContainsCycleI(aSrcIdx: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aSrcIdx);
  if VertexCount < 2 then
    exit(False);
  aCycle := nil;
  FindCycle(aSrcIdx, aCycle);
  Result := System.Length(aCycle) <> 0;
end;

function TGSimpleDigraph.ContainsEulerianCycle: Boolean;
var
  I, d: SizeInt;
begin
  if VertexCount < 2 then
    exit(False);
  d := 0;
  for I := 0 to Pred(VertexCount) do
    begin
      if InDegreeI(I) <> OutDegreeI(I) then
        exit(False);
      d += DegreeI(I);
    end;
  Result := d > 0;
end;

function TGSimpleDigraph.FindEulerianCycle: TIntArray;
var
  g: TSkeleton;
  Stack, Path: TIntStack;
  s, d: SizeInt;
begin
  Result := nil;
  if not ContainsEulerianCycle then
    exit;
  g := CreateSkeleton;
  s := 0;
  while g.Degree[s] = 0 do
    Inc(s);
  {%H-}Stack.Push(s);
  while Stack.TryPeek(s) do
    if g[s]^.FindFirst(d) then
      begin
        g.RemoveEdge(s, d);
        Stack.Push(d);
      end
    else
      {%H-}Path.Push(Stack.Pop{%H-});
  System.SetLength(Result, Path.Count);
  d := 0;
  for s in Path.Reverse do
    begin
      Result[d] := s;
      Inc(d);
    end;
end;

function TGSimpleDigraph.IsStrongConnected: Boolean;
var
  Dummy: TIntArray;
begin
  Result := FindStrongComponents(Dummy) = 1;
end;

function TGSimpleDigraph.FindStrongComponents(out aCompIds: TIntArray): SizeInt;
var
  m: TSquareBitMatrix;
begin
  if IsEmpty then
    exit(0);
  if VertexCount = 1 then
    begin
      aCompIds := [0];
      exit(1);
    end;
  if ReachabilityValid then
    begin
      aCompIds := System.Copy(FReachabilityMatrix.FIds);
      exit(FReachabilityMatrix.Size);
    end;
  Result := SearchForStrongComponents(aCompIds);
  if Result = 1 then
    begin
      m := TSquareBitMatrix.Create(1);
      m[0, 0] := True;
      FReachabilityMatrix := TReachabilityMatrix.Create(m, aCompIds);
    end;
end;

function TGSimpleDigraph.GetStrongComponent(const aVertex: TVertex): TIntArray;
begin
  Result := GetStrongComponentI(IndexOf(aVertex));
end;

function TGSimpleDigraph.GetStrongComponentI(aIndex: SizeInt): TIntArray;
var
  Ids: TIntArray;
  I, J, ScCount: SizeInt;
begin
  Result := nil;
  CheckIndexRange(aIndex);
  if VertexCount = 1 then
    exit([0]);
  if ReachabilityValid then
    begin
      ScCount := FReachabilityMatrix.Size;
      if ScCount > 1 then
        Ids := FReachabilityMatrix.FIds
      else
        exit(CreateIntArrayRange);
    end
  else
    ScCount := SearchForStrongComponents(Ids);
  aIndex := Ids[aIndex];
  Result.Length := VertexCount;
  J := 0;
  for I := 0 to System.High(Ids) do
    if Ids[I] = aIndex then
      begin
        Result[J] := I;
        Inc(J);
      end;
  Result.Length := J;
end;

procedure TGSimpleDigraph.BuildReachabilityMatrix;
var
  Ids: TIntArray;
  ScCount: SizeInt;
begin
  if IsEmpty or ReachabilityValid then
    exit;
  ScCount := SearchForStrongComponents(Ids);
  FReachabilityMatrix := GetReachabilityMatrix(Ids, ScCount);
end;

function TGSimpleDigraph.TryBuildReachabilityMatrix(const aScIds: TIntArray; aScCount: SizeInt): Boolean;
var
  I: SizeInt;
begin
  if IsEmpty or ReachabilityValid then
    exit(False);
  if aScIds.Length <> VertexCount then
    exit(False);
  if SizeUInt(aScCount) >= SizeUInt(VertexCount) then
    exit(False);
  for I in aScIds do
    if SizeUInt(I) >= SizeUInt(aScCount) then
      exit(False);
  Result := True;
  FReachabilityMatrix := GetReachabilityMatrix(System.Copy(aScIds), aScCount);
end;

function TGSimpleDigraph.FindMetrics(out aRadius, aDiameter: SizeInt): Boolean;
begin
  Result := IsStrongConnected;
  if Result then
    DoFindMetrics(aRadius, aDiameter);
end;

function TGSimpleDigraph.FindCenter: TIntArray;
var
  Eccs: TIntArray;
  I, J, Radius, Diam: SizeInt;
begin
  Result := nil;
  if not IsStrongConnected then
    exit;
  Eccs := DoFindMetrics(Radius, Diam);
  Result.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] = Radius then
      begin
        Result[J] := I;
        Inc(J);
      end;
  Result.Length := J;
end;

function TGSimpleDigraph.FindPeripheral: TIntArray;
var
  Eccs: TIntArray;
  I, J, Radius, Diam: SizeInt;
begin
  Result := nil;
  if not IsStrongConnected then
    exit;
  Eccs := DoFindMetrics(Radius, Diam);
  Result.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] = Diam then
      begin
        Result[J] := I;
        Inc(J);
      end;
  Result.Length := J;
end;

function TGSimpleDigraph.ShortestPath(const aSrc, aDst: TVertex): TIntArray;
begin
  Result := ShortestPathI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleDigraph.ShortestPathI(aSrc, aDst: SizeInt): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(nil);
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    exit(nil);
  Result := GetShortestPath(aSrc, aDst);
end;

function TGSimpleDigraph.IsFlowGraph(const aSource: TVertex): Boolean;
begin
  Result := IsFlowGraphI(IndexOf(aSource));
end;

function TGSimpleDigraph.IsFlowGraphI(aSrcIdx: SizeInt): Boolean;
begin
  Result := BfsTraversalI(aSrcIdx) = VertexCount;
end;

function TGSimpleDigraph.IsFlowGraph(const aSource: TVertex; out aMissed: TIntArray): Boolean;
begin
  Result := IsFlowGraphI(IndexOf(aSource), aMissed);
end;

function TGSimpleDigraph.IsFlowGraphI(aSrcIdx: SizeInt; out aMissed: TIntArray): Boolean;
var
  Queue: TIntArray;
  UnVisited: TBoolVector;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  Result := False;
  aMissed := nil;
  CheckIndexRange(aSrcIdx);
  if VertexCount < 2 then
    exit(True);
  UnVisited.InitRange(VertexCount);
  Queue.Length := VertexCount;
  UnVisited.UncBits[aSrcIdx] := False;
  Queue[qTail] := aSrcIdx;
  Inc(qTail);
  while qHead < qTail do
    begin
      aSrcIdx := Queue[qHead];
      Inc(qHead);
      for p in AdjLists[aSrcIdx]^ do
        if UnVisited.UncBits[p^.Key] then
          begin
            Queue[qTail] := p^.Key;
            Inc(qTail);
            UnVisited.UncBits[p^.Key] := False;
          end;
    end;
  Result := UnVisited.IsEmpty;
  if not Result then
    aMissed := UnVisited.ToArray;
end;

function TGSimpleDigraph.FindDomTree(const aSource: TVertex; out aSize: SizeInt): TIntArray;
begin
  Result := FindDomTreeI(IndexOf(aSource), aSize);
end;

function TGSimpleDigraph.FindDomTreeI(aSrcIdx: SizeInt; out aSize: SizeInt): TIntArray;
var
  Preds: TIntSetArray;
begin
  Result := nil;
  CheckIndexRange(aSrcIdx);
  if VertexCount < 2 then
    begin
      aSize := 1;
      exit([NULL_INDEX]);
    end;
  Result := GetDomTree(aSrcIdx, aSize, Preds);
  Result[aSrcIdx] := NULL_INDEX;
end;

function TGSimpleDigraph.FindDomTreeSnca(const aSource: TVertex; out aSize: SizeInt): TIntArray;
begin
  Result := FindDomTreeSncaI(IndexOf(aSource), aSize);
end;

function TGSimpleDigraph.FindDomTreeSncaI(aSrcIdx: SizeInt; out aSize: SizeInt): TIntArray;
var
  Preds: TIntSetArray;
  Ord2Idx, Idx2Ord: TIntArray;
begin
  Result := nil;
  CheckIndexRange(aSrcIdx);
  if VertexCount < 2 then
    begin
      aSize := 1;
      exit([NULL_INDEX]);
    end;
  Result := GetDomTreeSnca(aSrcIdx, aSize, Preds, Ord2Idx, Idx2Ord);
  Result[aSrcIdx] := NULL_INDEX;
end;

function TGSimpleDigraph.IsDomTree(const aTree: TIntArray; constref aSource: TVertex): Boolean;
begin
  Result := IsDomTreeI(aTree, IndexOf(aSource));
end;

function TGSimpleDigraph.IsDomTreeI(const aTree: TIntArray; aSrcIdx: SizeInt): Boolean;
begin
  Result := False;
  CheckIndexRange(aSrcIdx);
  if aTree.Length <> VertexCount then
    exit(False);
  if aTree[aSrcIdx] <> NULL_INDEX then
    exit(False);
  if VertexCount < 2 then
    exit(True);
  Result := TestIsDomTree(aTree, aSrcIdx);
end;

function TGSimpleDigraph.ExtractDomSet(const aVertex: TVertex; const aDomTree: TIntArray): TIntArray;
begin
  Result := ExtractDomSetI(IndexOf(aVertex), aDomTree);
end;

function TGSimpleDigraph.ExtractDomSetI(aVertexIdx: SizeInt; const aDomTree: TIntArray): TIntArray;
var
  DomSet: TIntSet;
  Len: SizeInt;
begin
  if aDomTree.Length <> VertexCount then
    raise EGraphError.Create(SEInvalidTreeInst);
  Len := VertexCount;
  repeat
    if SizeUInt(aVertexIdx) >= SizeUInt(VertexCount) then
      raise EGraphError.Create(SEInvalidTreeInst);
    {%H-}DomSet.Push(aVertexIdx);
    Dec(Len);
    if Len < 0 then
      raise EGraphError.Create(SEInvalidTreeInst);
    aVertexIdx := aDomTree[aVertexIdx];
  until aVertexIdx < 0;
  Result := DomSet.ToArray;
end;

function TGSimpleDigraph.CreateDomTree(const aSource: TVertex): TDomTree;
begin
  Result := CreateDomTreeI(IndexOf(aSource));
end;

function TGSimpleDigraph.CreateDomTreeI(aSrcIdx: SizeInt): TDomTree;
var
  Tree: TIntArray;
  I: SizeInt;
begin
  Result := Default(TDomTree);
  Tree := FindDomTreeI(aSrcIdx, I);
  Result.Init(Tree, aSrcIdx);
end;

function TGSimpleDigraph.CreateDomTreeSnca(const aSource: TVertex): TDomTree;
begin
  Result := CreateDomTreeSncaI(IndexOf(aSource));
end;

function TGSimpleDigraph.CreateDomTreeSncaI(aSrcIdx: SizeInt): TDomTree;
var
  Tree: TIntArray;
  I: SizeInt;
begin
  Result := Default(TDomTree);
  Tree := FindDomTreeSncaI(aSrcIdx, I);
  Result.Init(Tree, aSrcIdx);
end;

function TGSimpleDigraph.FindDomFrontiers(const aSource: TVertex; out aDomTree: TDomTree): TIntMatrix;
begin
  Result := FindDomFrontiersI(IndexOf(aSource), aDomTree);
end;

function TGSimpleDigraph.FindDomFrontiersI(aSrcIdx: SizeInt; out aDomTree: TDomTree): TIntMatrix;
var
  Preds, DomFronts: TIntSetArray;
  Ord2Idx, Idx2Ord, Tree: TIntArray;
  I, PreOrd, Curr, Next: SizeInt;
begin
  aDomTree := Default(TDomTree);
  Result := nil;
  CheckIndexRange(aSrcIdx);
  Tree := GetDomTreeSnca(aSrcIdx, I, Preds, Ord2Idx, Idx2Ord);
  System.SetLength(DomFronts, VertexCount);
  for I := 0 to Pred(VertexCount) do
    if I <> aSrcIdx then
      begin
        PreOrd := Idx2Ord[I];
        if Preds[PreOrd].Count > 1 then
          for Curr in Preds[PreOrd] do
            begin
              Next := Ord2Idx[Curr];
              while (Next <> Tree[I]) and (Next <> I) do
                begin
                  DomFronts[Next].Add(I);
                  Next := Tree[Next];
                end;
            end;
      end;
  Tree[aSrcIdx] := NULL_INDEX;
  aDomTree.Init(Tree, aSrcIdx);
  Tree := nil;
  System.SetLength(Result, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Result[I] := DomFronts[I].ToArray;
end;

function TGSimpleDigraph.TopologicalSort(aOrder: TSortOrder): TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0]);
  Result := TopoSort;
  if aOrder = soDesc then
    TIntHelper.Reverse(Result);
end;

function TGSimpleDigraph.TopologicalSort(out aSorted: TIntArray; aOrder: TSortOrder): Boolean;
begin
  aSorted := nil;
  Result := True;
  if IsEmpty then
    exit;
  if VertexCount = 1 then
    begin
      aSorted := [0];
      exit;
    end;
  Result := TopoSort(aSorted);
  if Result and (aOrder = soDesc) then
    TIntHelper.Reverse(aSorted);
end;

function TGSimpleDigraph.IsTopoSorted(const aTestSet: TIntArray; aSortOrder: TSortOrder): Boolean;
var
  Visited: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
begin
  if aTestSet.Length <> VertexCount then
    exit(False);
  if VertexCount < 2 then
    exit(True);
  Visited.Capacity := VertexCount;
  for I in aTestSet do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then
        exit(False);
      if Visited.UncBits[I] then
        exit(False);
      Visited.UncBits[I] := True;
    end;
  Visited.ClearBits;
  if aSortOrder = soAsc then
    for I := 0 to Pred(VertexCount) do
      begin
        J := aTestSet[I];
        for p in AdjLists[J]^ do
          if Visited.UncBits[p^.Key] then
            exit(False);
        Visited.UncBits[J] := True;
      end
  else
    for I := Pred(VertexCount) downto 0 do
      begin
        J := aTestSet[I];
        for p in AdjLists[J]^ do
          if Visited.UncBits[p^.Key] then
            exit(False);
        Visited.UncBits[J] := True;
      end;
  Result := True;
end;

function TGSimpleDigraph.IsDag: Boolean;
begin
  if VertexCount < 2 then
    exit(True);
  Result := not CycleExists;
end;

function TGSimpleDigraph.DagLongestPathsMap(const aSrc: TVertex): TIntArray;
begin
  Result := DagLongestPathsMapI(IndexOf(aSrc));
end;

function TGSimpleDigraph.DagLongestPathsMapI(aSrc: SizeInt): TIntArray;
var
  c: TIntArray;
begin
  CheckIndexRange(aSrc);
  if VertexCount = 1 then
    exit([0]);
  if FindCycle(aSrc, c) then
    exit(nil);
  Result := GetDagLongestPaths(aSrc);
end;

function TGSimpleDigraph.DagLongestPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TIntArray;
begin
  Result := DagLongestPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGSimpleDigraph.DagLongestPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TIntArray;
begin
  CheckIndexRange(aSrc);
  if VertexCount = 1 then
    begin
      aPathTree := [NULL_INDEX];
      exit([0]);
    end;
  if FindCycle(aSrc, aPathTree) then
    exit(nil);
  Result := GetDagLongestPaths(aSrc, aPathTree);
end;

function TGSimpleDigraph.DagLongestPaths: TIntArray;
var
  TopoOrd: TIntArray;
  I, J, d: SizeInt;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0]);
  if CycleExists then
    exit(nil);
  TopoOrd := TopologicalSort(soDesc);
  Result := CreateIntArray(0);
  for I := 1 to Pred(VertexCount) do
    for J := 0 to Pred(I) do
      if AdjacentI(TopoOrd[I], TopoOrd[J]) then
        begin
          d := Succ(Result[TopoOrd[J]]);
          if d > Result[TopoOrd[I]] then
            Result[TopoOrd[I]] := d;
        end;
end;

function TGSimpleDigraph.FindHamiltonCycles(const aSource: TVertex; aCount: SizeInt;
  out aCycles: TIntArrayVector; aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonCyclesI(IndexOf(aSource), aCount, aCycles, aTimeOut);
end;

function TGSimpleDigraph.FindHamiltonCyclesI(aSourceIdx, aCount: SizeInt; out aCycles: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonSearch;
  //I: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  {%H-}aCycles.Clear;
  if VertexCount < 2 then
    exit(False);
  if not IsStrongConnected then
    exit(False);
  //for I := 0 to Pred(VertexCount) do
  //  if (FNodeList[I].Tag = 0) or FNodeList[I].AdjList.IsEmpty then
  //    exit(False);
  Result := Helper.FindCycles(Self, aSourceIdx, aCount, aTimeOut, @aCycles);
end;

function TGSimpleDigraph.IsHamiltonCycle(const aTestCycle: TIntArray; aSourceIdx: SizeInt): Boolean;
var
  VertSet: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  if aTestCycle.Length <> Succ(VertexCount) then
    exit(False);
  if (aTestCycle[0] <> aSourceIdx) or (aTestCycle[VertexCount] <> aSourceIdx) then
    exit(False);
  VertSet.Capacity := VertexCount;
  Next := aSourceIdx;
  VertSet.UncBits[aSourceIdx] := True;
  for I := 1 to Pred(VertexCount) do
    begin
      Curr := Next;
      Next := aTestCycle[I];
      if SizeUInt(Next) >= SizeUInt(VertexCount) then
        exit(False);
      if VertSet.UncBits[Next] then
        exit(False);
      VertSet.UncBits[Next] := True;
      if not AdjLists[Curr]^.Contains(Next) then
        exit(False);
    end;
  Result := True;
end;

function TGSimpleDigraph.FindHamiltonPaths(const aSrc: TVertex; aCount: SizeInt; out aPaths: TIntArrayVector;
  aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonPathsI(IndexOf(aSrc), aCount, aPaths, aTimeOut);
end;

function TGSimpleDigraph.FindHamiltonPathsI(aSrcIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonSearch;
  I, SnkCount: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  {%H-}aPaths.Clear;
  if VertexCount < 2 then
    exit(False);
  if FNodeList[aSrcIdx].AdjList.IsEmpty then
    exit(False);
  SnkCount := 0;
  for I := 0 to Pred(VertexCount) do
    if I <> aSrcIdx then
      begin
        if FNodeList[I].Tag = 0  then
          exit(False);
        if FNodeList[I].AdjList.IsEmpty then
          begin
            if SnkCount > 0 then
              exit(False);
            Inc(SnkCount);
          end;
      end;
  Result := Helper.FindPaths(Self, aSrcIdx, aCount, aTimeOut, @aPaths);
end;

function TGSimpleDigraph.IsHamiltonPath(const aTestPath: TIntArray; aSrcIdx: SizeInt): Boolean;
var
  VertSet: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  if aTestPath.Length <> VertexCount then
    exit(False);
  if aTestPath[0] <> aSrcIdx then
    exit(False);
  VertSet.Capacity := VertexCount;
  Next := aSrcIdx;
  VertSet.UncBits[aSrcIdx] := True;
  for I := 1 to Pred(VertexCount) do
    begin
      Curr := Next;
      Next := aTestPath[I];
      if SizeUInt(Next) >= SizeUInt(VertexCount) then
        exit(False);
      if VertSet.UncBits[Next] then
        exit(False);
      VertSet.UncBits[Next] := True;
      if not AdjLists[Curr]^.Contains(Next) then
        exit(False);
    end;
  Result := True;
end;

{ TGFlowChart }

procedure TGFlowChart.ReadData(aStream: TStream; out aValue: TDummy);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
end;

procedure TGFlowChart.WriteData(aStream: TStream; const aValue: TDummy);
begin
  aStream.WriteBuffer(aValue, SizeOf(aValue));
end;

function TGFlowChart.Clone: TGFlowChart;
begin
  Result := TGFlowChart.Create;
  Result.AssignGraph(Self);
end;

function TGFlowChart.Reverse: TGFlowChart;
begin
  Result := TGFlowChart.Create;
  Result.AssignReverse(Self);
end;

function TGFlowChart.InducedSubgraph(const aVertexList: TIntArray): TGFlowChart;
begin
  Result := TGFlowChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

procedure TGFlowChart.SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToStream(aStream, aOnWriteVertex, @WriteData);
end;

procedure TGFlowChart.LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromStream(aStream, aOnReadVertex, @ReadData);
end;

procedure TGFlowChart.SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToFile(aFileName, aOnWriteVertex, @WriteData);
end;

procedure TGFlowChart.LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromFile(aFileName, aOnReadVertex, @ReadData);
end;

procedure TGFlowChart.SetUnionOf(aChart: TGFlowChart);
var
  v: TVertex;
  e: TEdge;
begin
  for v in aChart.Vertices do
    AddVertex(v);
  for e in aChart.Edges do
    AddEdge(aChart[e.Source], aChart[e.Destination]);
end;

procedure TGFlowChart.SetIntersectionOf(aChart: TGFlowChart);
var
  Tmp: TGFlowChart;
  s, d: TVertex;
  e: TEdge;
begin
  Tmp := TGFlowChart.Create;
  try
    Tmp.Title := Title;
    Tmp.Description := Description;
    for s in Vertices do
      if aChart.ContainsVertex(s) then
        Tmp.AddVertex(s);
    for e in Edges do
      begin
        s := Items[e.Source];
        d := Items[e.Destination];
        if aChart.ContainsEdge(s, d) then
          Tmp.AddEdge(s, d);
      end;
    AssignGraph(Tmp);
  finally
    Tmp.Free;
  end;
end;

{ TGDigraphDotWriter }

procedure TGDigraphDotWriter.WriteEdges(aGraph: TGraph; aList: TStrings);
var
  e: TGraph.TEdge;
  s: string;
begin
  for e in aGraph.Edges do
    begin
      if Assigned(OnWriteEdge) then
        s := OnWriteEdge(aGraph, e)
      else
        s := DefaultWriteEdge(aGraph, e);
      aList.Add(s);
    end;
end;

constructor TGDigraphDotWriter.Create;
begin
  FGraphMark := 'digraph ';
  FEdgeMark := '->';
end;

{ TIntFlowChart }

procedure TIntFlowChart.WriteVertex(aStream: TStream; const aValue: Integer);
begin
  aStream.WriteBuffer(NtoLE(aValue), SizeOf(aValue));
end;

procedure TIntFlowChart.ReadVertex(aStream: TStream; out aValue: Integer);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue := LEtoN(aValue);
end;

function TIntFlowChart.Clone: TIntFlowChart;
begin
  Result := TIntFlowChart.Create;
  Result.AssignGraph(Self);
end;

function TIntFlowChart.Reverse: TIntFlowChart;
begin
  Result := TIntFlowChart.Create;
  Result.AssignReverse(Self);
end;

function TIntFlowChart.InducedSubgraph(const aVertexList: TIntArray): TIntFlowChart;
begin
  Result := TIntFlowChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

procedure TIntFlowChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TIntFlowChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TIntFlowChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TIntFlowChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

function TIntFlowChart.AddVertexRange(aFrom, aTo: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := aFrom to aTo do
    Result += Ord(AddVertex(I));
end;

function TIntFlowChart.AddEdges(const aVertexList: array of Integer): Integer;
var
  I: SizeInt = 0;
begin
  Result := EdgeCount;
  while I < System.High(aVertexList) do
    begin
      AddEdge(aVertexList[I], aVertexList[Succ(I)]);
      I += 2;
    end;
  Result := EdgeCount - Result;
end;

{ TIntFlowChartDotWriter }

function TIntFlowChartDotWriter.DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string;
begin
  Result := IntToStr(aGraph[aEdge.Source]) + FEdgeMark + IntToStr(aGraph[aEdge.Destination]) + ';';
end;

{ TStrFlowChart }

procedure TStrFlowChart.WriteVertex(aStream: TStream; const aValue: string);
var
  Len: SizeInt;
  sLen: SmallInt;
begin
  Len := System.Length(aValue);
  if Len > High(SmallInt) then
    raise EGraphError.CreateFmt(SEStrLenExceedFmt, [Len]);
  sLen := Len;
  aStream.WriteBuffer(sLen, SizeOf(sLen));
  aStream.WriteBuffer(Pointer(aValue)^, Len);
end;

procedure TStrFlowChart.ReadVertex(aStream: TStream; out aValue: string);
var
  Len: SmallInt;
begin
  aStream.ReadBuffer(Len{%H-}, SizeOf(Len));
  System.SetLength(aValue, Len);
  aStream.ReadBuffer(Pointer(aValue)^, Len);
end;

function TStrFlowChart.Clone: TStrFlowChart;
begin
  Result := TStrFlowChart.Create;
  Result.AssignGraph(Self);
end;

function TStrFlowChart.Reverse: TStrFlowChart;
begin
  Result := TStrFlowChart.Create;
  Result.AssignReverse(Self);
end;

function TStrFlowChart.InducedSubgraph(const aVertexList: TIntArray): TStrFlowChart;
begin
  Result := TStrFlowChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

procedure TStrFlowChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TStrFlowChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TStrFlowChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TStrFlowChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

function TStrFlowChart.AddEdges(const aVertexList: array of string): Integer;
var
  I: SizeInt = 0;
begin
  Result := EdgeCount;
  while I < System.High(aVertexList) do
    begin
      AddEdge(aVertexList[I], aVertexList[Succ(I)]);
      I += 2;
    end;
  Result := EdgeCount - Result;
end;

{ TStrFlowChartDotWriter }

function TStrFlowChartDotWriter.DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string;
begin
  Result := '"' + aGraph[aEdge.Source] + '"' + FEdgeMark + '"' + aGraph[aEdge.Destination] + '";';
end;

{ TGWeightedDigraph }

function TGWeightedDigraph.CreateEdgeArray: TEdgeArray;
var
  I: SizeInt = 0;
  e: TEdge;
begin
  System.SetLength(Result, EdgeCount);
  for e in Edges do
    begin
      Result[I] := TWeightEdge.Create(e.Source, e.Destination, e.Data.Weight);
      Inc(I);
    end;
end;

procedure TGWeightedDigraph.GetDagMinPaths(aSrc: SizeInt; var aWeights: TWeightArray);
var
  Queue: TIntArray;
  Visited: TBoolVector;
  Curr, Next: SizeInt;
  w: TWeight;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  Queue := CreateIntArray;
  TWeightHelper.ResizeAndFill(aWeights, VertexCount, TWeight.INF_VALUE);
  Visited.Capacity := VertexCount;
  Visited.UncBits[aSrc] := True;
  aWeights[aSrc] := 0;
  Queue[qTail] := aSrc;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := Queue[qHead];
      Inc(qHead);
      for p in AdjLists[Curr]^ do
        begin
          Next := p^.Key;
          if not Visited.UncBits[Next] then
            begin
              Visited.UncBits[Next] := True;
              Queue[qTail] := Next;
              Inc(qTail);
            end;
          w := aWeights[Curr] + p^.Data.Weight;
          if aWeights[Next] > w then
            aWeights[Next] := w;
        end;
    end;
end;

procedure TGWeightedDigraph.GetDagMinPaths(aSrc: SizeInt; var aTree: TIntArray; var aWeights: TWeightArray);
var
  Queue: TIntArray;
  Curr, Next: SizeInt;
  w: TWeight;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  Queue := CreateIntArray;
  aTree := CreateIntArray;
  TWeightHelper.ResizeAndFill(aWeights, VertexCount, TWeight.INF_VALUE);
  aWeights[aSrc] := 0;
  Queue[qTail] := aSrc;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := Queue[qHead];
      Inc(qHead);
      for p in AdjLists[Curr]^ do
        begin
          Next := p^.Key;
          if aTree[Next] = NULL_INDEX then
            begin
              Queue[qTail] := Next;
              Inc(qTail);
            end;
          w := aWeights[Curr] + p^.Data.Weight;
          if aWeights[Next] > w then
            begin
              aWeights[Next] := w;
              aTree[Next] := Curr;
            end;
        end;
    end;
end;

function TGWeightedDigraph.GetDagMaxPaths(aSrc: SizeInt): TWeightArray;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjItemEnumArray;
  Visited: TBoolVector;
  Curr, Next: SizeInt;
  p: PAdjItem;
  w: TWeight;
begin
  AdjEnums := CreateAdjItemEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Result := TWeightHelper.CreateWeightArrayNI(VertexCount);
  Visited.Capacity := VertexCount;
  Visited.UncBits[aSrc] := True;
  Result[aSrc] := 0;
  Stack.Push(aSrc);
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        p := AdjEnums[Curr].Current;
        Next := p^.Key;
        if not Visited.UncBits[Next] then
          begin
            Visited.UncBits[Next] := True;
            Stack.Push(Next);
          end;
        w := Result[Curr] + p^.Data.Weight;
        if w > Result[Next] then
          Result[Next] := w;
      end
    else
      Stack.Pop;
end;

function TGWeightedDigraph.GetDagMaxPaths(aSrc: SizeInt; out aTree: TIntArray): TWeightArray;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjItemEnumArray;
  Curr, Next: SizeInt;
  p: PAdjItem;
  w: TWeight;
begin
  AdjEnums := CreateAdjItemEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  Result := TWeightHelper.CreateWeightArrayNI(VertexCount);
  aTree := CreateIntArray;
  Result[aSrc] := 0;
  {%H-}Stack.Push(aSrc);
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        p := AdjEnums[Curr].Current;
        Next := p^.Key;
        if aTree[Next] = NULL_INDEX then
          Stack.Push(Next);
        w := Result[Curr] + p^.Data.Weight;
        if w > Result[Next] then
          begin
            Result[Next] := w;
            aTree[Next] := Curr;
          end;
      end
    else
      Stack.Pop;
end;

class function TGWeightedDigraph.InfWeight: TWeight;
begin
  Result := TWeight.INF_VALUE;
end;

class function TGWeightedDigraph.NegInfWeight: TWeight;
begin
  Result := TWeight.NEGINF_VALUE;
end;

class function TGWeightedDigraph.wMin(L, R: TWeight): TWeight;
begin
  if L <= R then
    Result := L
  else
    Result := R;
end;

class function TGWeightedDigraph.wMax(L, R: TWeight): TWeight;
begin
  if L >= R then
    Result := L
  else
    Result := R;
end;

class function TGWeightedDigraph.TotalWeight(const aEdges: TEdgeArray): TWeight;
var
  e: TWeightEdge;
begin
  Result := TWeight(0);
  for e in aEdges do
    Result += e.Weight;
end;

class function TGWeightedDigraph.EdgeArray2IntEdgeArray(const a: TEdgeArray): TIntEdgeArray;
var
  I: SizeInt = 0;
  e: TWeightEdge;
begin
  System.SetLength(Result, System.Length(a));
  for e in a do
    begin
      Result[I] := TIntEdge.Create(e.Source, e.Destination);
      Inc(I);
    end;
end;

function TGWeightedDigraph.ContainsNegWeightEdge: Boolean;
var
  e: TEdge;
begin
  for e in Edges do
    if e.Data.Weight < 0 then
      exit(True);
  Result := False;
end;

function TGWeightedDigraph.ContainsNegCycle(const aRoot: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsNegCycleI(IndexOf(aRoot), aCycle);
end;

function TGWeightedDigraph.ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aRootIdx);
  if VertexCount > 1 then
    begin
      aCycle := TWeightHelper.NegCycleDetect(Self, aRootIdx);
      Result := aCycle <> nil;
    end
  else
    begin
      aCycle := nil;
      Result := False;
    end;
end;

function TGWeightedDigraph.Clone: TGWeightedDigraph;
begin
  Result := TGWeightedDigraph.Create;
  Result.AssignGraph(Self);
end;

function TGWeightedDigraph.Reverse: TGWeightedDigraph;
begin
  Result := TGWeightedDigraph.Create;
  Result.AssignReverse(Self);
end;

function TGWeightedDigraph.InducedSubgraph(const aVertexList: TIntArray): TGWeightedDigraph;
begin
  Result := TGWeightedDigraph.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGWeightedDigraph.MinPathsMap(const aSrc: TVertex): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc));
end;

function TGWeightedDigraph.MinPathsMapI(aSrc: SizeInt): TWeightArray;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.DijkstraSssp(Self, aSrc)
  else
    Result := [TWeight(0)];
end;

function TGWeightedDigraph.MinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedDigraph.MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.DijkstraSssp(Self, aSrc, aPathTree)
  else
    begin
      aPathTree := [NULL_INDEX];
      Result := [TWeight(0)];
    end;
end;

function TGWeightedDigraph.MinPath(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
begin
  Result := MinPathI(IndexOf(aSrc), IndexOf(aDst), aWeight);
end;

function TGWeightedDigraph.MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedDigraph.MinPathBiDir(const aSrc, aDst: TVertex; aRev: TGWeightedDigraph;
  out aWeight: TWeight): TIntArray;
begin
  Result := MinPathBiDirI(IndexOf(aSrc), IndexOf(aDst), aRev, aWeight);
end;

function TGWeightedDigraph.MinPathBiDirI(aSrc, aDst: SizeInt; aRev: TGWeightedDigraph;
  out aWeight: TWeight): TIntArray;
var
  d: TEdgeData;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  Result := TWeightHelper.BiDijkstraPath(Self, aRev, aSrc, aDst, aWeight);
end;

function TGWeightedDigraph.MinPathAStar(const aSrc, aDst: TVertex; out aWeight: TWeight;
  aEst: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aDst), aWeight, aEst);
end;

function TGWeightedDigraph.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  if aEst <> nil then
    Result := TWeightHelper.AStar(Self, aSrc, aDst, aWeight, aEst)
  else
    Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedDigraph.MinPathNBAStar(const aSrc, aDst: TVertex; aRev: TGWeightedDigraph;
  out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  Result := MinPathNBAStarI(IndexOf(aSrc), IndexOf(aSrc), aRev, aWeight, aEst);
end;

function TGWeightedDigraph.MinPathNBAStarI(aSrc, aDst: SizeInt; aRev: TGWeightedDigraph;
  out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  if aEst <> nil then
    Result := TWeightHelper.NBAStar(Self, aRev, aSrc, aDst, aWeight, aEst)
  else
    Result := TWeightHelper.BiDijkstraPath(Self, aRev, aSrc, aDst, aWeight);
end;

function TGWeightedDigraph.FindMinPath(const aSrc, aDst: TVertex; out aPath: TIntArray;
  out aWeight: TWeight): Boolean;
begin
  Result := FindMinPathI(IndexOf(aSrc), IndexOf(aDst), aPath, aWeight);
end;

function TGWeightedDigraph.FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      aPath := nil;
      exit(True);
    end;
  if ReachabilityValid and not FReachabilityMatrix.Reachable(aSrc, aDst) then
    begin
      aWeight := InfWeight;
      aPath := nil;
      exit(False);
    end;
  Result := TWeightHelper.BfmtPath(Self, aSrc, aDst, aPath, aWeight);
end;

function TGWeightedDigraph.FindMinPathsMap(const aSrc: TVertex; out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aWeights);
end;

function TGWeightedDigraph.FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.BfmtSssp(Self, aSrc, aWeights)
  else
    begin
      aWeights := [TWeight(0)];
      Result := True;
    end;
end;

function TGWeightedDigraph.FindMinPathsMap(const aSrc: TVertex; out aPaths: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aPaths, aWeights);
end;

function TGWeightedDigraph.FindMinPathsMapI(aSrc: SizeInt; out aPaths: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.BfmtSssp(Self, aSrc, aPaths, aWeights)
  else
    begin
      aPaths := [NULL_INDEX];
      aWeights := [TWeight(0)];
      Result := True;
    end;
end;

function TGWeightedDigraph.CreateWeightsMatrix: TWeightMatrix;
begin
  Result := TWeightHelper.CreateWeightsMatrix(Self);
end;

function TGWeightedDigraph.FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
begin
  if VertexCount > 1 then
    if Density <= DENSE_CUTOFF then
      if Density <= JOHNSON_CUTOFF then
        Result := TWeightHelper.BfmtApsp(Self, True, aPaths)
      else
        Result := TWeightHelper.JohnsonApsp(Self, aPaths)
    else
      Result := TWeightHelper.FloydApsp(Self, aPaths)
  else
    begin
      Result := True;
      if VertexCount = 0 then
        aPaths := nil
      else
        aPaths := [[TApspCell.Create(TWeight(0), NULL_INDEX)]];
    end;
end;

function TGWeightedDigraph.ExtractMinPath(const aSrc, aDst: TVertex; const aPaths: TApspMatrix): TIntArray;
begin
  Result := ExtractMinPathI(IndexOf(aSrc), IndexOf(aDst), aPaths);
end;

function TGWeightedDigraph.ExtractMinPathI(aSrc, aDst: SizeInt; const aPaths: TApspMatrix): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    Result := nil
  else
    Result := TWeightHelper.ExtractMinPath(aSrc, aDst, aPaths);
end;

function TGWeightedDigraph.FindEccentricity(const aVertex: TVertex; out aValue: TWeight): Boolean;
begin
  Result := FindEccentricityI(IndexOf(aVertex), aValue);
end;

function TGWeightedDigraph.FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
var
  Weights: TWeightArray;
  I: SizeInt;
  w: TWeight;
begin
  aValue := 0;
  Result := FindMinPathsMapI(aIndex, Weights);
  if not Result then
    exit;
  for I := 0 to System.High(Weights) do
    begin
      w := Weights[I];
      if (w < TWeight.INF_VALUE) and (w > aValue) then
        aValue := w;
    end;
end;

function TGWeightedDigraph.FindWeightedMetrics(out aRadius, aDiameter: TWeight): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Weights: TWeightArray;
  Ids: TIntArray;
  I, J: SizeInt;
  Ecc, w: TWeight;
begin
  aRadius := TWeight.INF_VALUE;
  aDiameter := TWeight.INF_VALUE;
  if IsEmpty then
    exit(False);
  I := FindStrongComponents(Ids);
  if I > 1 then
    exit(False);
  Ids := nil;
  Result := TWeightHelper.BfmtReweight(Self, Weights) < 0;
  if not Result then
    exit;
  Weights := nil;
  aDiameter := 0;
  Bfmt := TWeightHelper.TBfmt.Create(Self, True);
  for I := 0 to Pred(VertexCount) do
    begin
      Bfmt.Sssp(I);
      Ecc := 0;
      with Bfmt do
        for J := 0 to Pred(VertexCount) do
          if I <> J then
            begin
              w := Nodes[J].Weight;
              if (w < TWeight.INF_VALUE) and (w > Ecc) then
                Ecc := w;
            end;
      if Ecc < aRadius then
        aRadius := Ecc;
      if Ecc > aDiameter then
        aDiameter := Ecc;
    end;
end;

function TGWeightedDigraph.FindWeightedCenter(out aCenter: TIntArray): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Eccs: TWeightArray;
  Ids: TIntArray;
  I, J: SizeInt;
  Radius, Ecc, w: TWeight;
begin
  aCenter := nil;
  if IsEmpty then
    exit(False);
  I := FindStrongComponents(Ids);
  if I > 1 then
    exit(False);
  Ids := nil;
  Result := TWeightHelper.BfmtReweight(Self, Eccs) < 0;
  if not Result then
    exit;
  Bfmt := TWeightHelper.TBfmt.Create(Self, True);
  Radius := TWeight.INF_VALUE;
  for I := 0 to Pred(VertexCount) do
    begin
      Bfmt.Sssp(I);
      Ecc := 0;
      with Bfmt do
        for J := 0 to Pred(VertexCount) do
          if I <> J then
            begin
              w := Nodes[J].Weight;
              if (w < TWeight.INF_VALUE) and (w > Ecc) then
                Ecc := w;
            end;
      Eccs[I] := Ecc;
      if Ecc < Radius then
        Radius := Ecc;
    end;
  aCenter.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] <= Radius then
      begin
        aCenter[J] := I;
        Inc(J);
      end;
  aCenter.Length := J;
end;

function TGWeightedDigraph.DagMinPathsMap(const aSrc: TVertex): TWeightArray;
begin
  Result := DagMinPathsMapI(IndexOf(aSrc));
end;

function TGWeightedDigraph.DagMinPathsMapI(aSrc: SizeInt): TWeightArray;
var
  c: TIntArray;
begin
  CheckIndexRange(aSrc);
  Result := nil;
  if FindCycle(aSrc, c) then
    exit;
  GetDagMinPaths(aSrc, Result);
end;

function TGWeightedDigraph.DagMinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := DagMinPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedDigraph.DagMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
begin
  CheckIndexRange(aSrc);
  Result := nil;
  if FindCycle(aSrc, aPathTree) then
    exit;
  GetDagMinPaths(aSrc, aPathTree{%H-}, Result);
end;

function TGWeightedDigraph.FindDagAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
var
  Weights: TWeightArray;
  Parents: TIntArray;
  I, J: SizeInt;
begin
  aPaths := nil;
  if IsEmpty then
    exit(False);
  if CycleExists then
    exit(False);
  Parents := nil;
  Weights := nil;
  System.SetLength(aPaths, VertexCount, VertexCount);
  for I := 0 to Pred(VertexCount) do
    begin
      GetDagMinPaths(I, Parents, Weights);
      for J := 0 to Pred(VertexCount) do
        aPaths[I, J] := TApspCell.Create(Weights[J], Parents[J]);
    end;
  Result := True;
end;

function TGWeightedDigraph.DagMaxPathsMap(const aSrc: TVertex): TWeightArray;
begin
  Result := DagMaxPathsMapI(IndexOf(aSrc));
end;

function TGWeightedDigraph.DagMaxPathsMapI(aSrc: SizeInt): TWeightArray;
var
  c: TIntArray;
begin
  CheckIndexRange(aSrc);
  if FindCycle(aSrc, c) then
    exit(nil);
  Result := GetDagMaxPaths(aSrc);
end;

function TGWeightedDigraph.DagMaxPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := DagMaxPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedDigraph.DagMaxPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
begin
  CheckIndexRange(aSrc);
  if FindCycle(aSrc, aPathTree) then
    exit(nil);
  Result := GetDagMaxPaths(aSrc, aPathTree);
end;

function TGWeightedDigraph.DagMaxPaths: TWeightArray;
var
  TopoOrd: TIntArray;
  I, J: SizeInt;
  w: TWeight;
  p: PAdjItem;
  pList: PAdjList;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([TWeight(0)]);
  if CycleExists then
    exit(nil);
  TopoOrd := TopologicalSort(soDesc);
  Result := TWeightHelper.CreateWeightArrayZ(VertexCount);
  for I := 1 to Pred(VertexCount) do
    begin
      pList := AdjLists[TopoOrd[I]];
      for J := 0 to Pred(I) do
        begin
          p := pList^.Find(TopoOrd[J]);
          if p <> nil then
            begin
              w := Result[TopoOrd[J]] + p^.Data.Weight;
              if w > Result[TopoOrd[I]] then
                Result[TopoOrd[I]] := w;
            end;
        end;
    end;
end;

{$I MaxFlow.inc}

{ TGDirectInt64Net }

function TGDirectInt64Net.Clone: TGDirectInt64Net;
begin
  Result := TGDirectInt64Net.Create;
  Result.AssignGraph(Self);
end;

function TGDirectInt64Net.Reverse: TGDirectInt64Net;
begin
  Result := TGDirectInt64Net.Create;
  Result.AssignReverse(Self);
end;

function TGDirectInt64Net.InducedSubgraph(const aVertexList: TIntArray): TGDirectInt64Net;
begin
  Result := TGDirectInt64Net.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGDirectInt64Net.FindMinWeightBipMatch(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  aMatch := nil;
  Result := IsBipartite(w, g);
  if Result then
    aMatch := TWeightHelper.MinBipMatch(Self, w, g);
end;

function TGDirectInt64Net.FindMaxWeightBipMatch(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  aMatch := nil;
  Result := IsBipartite(w, g);
  if Result then
    aMatch := TWeightHelper.MaxBipMatch(Self, w, g);
end;

function TGDirectInt64Net.GetNetworkState(const aSource, aSink: TVertex): TNetworkState;
begin
  Result := GetNetworkStateI(IndexOf(aSource), IndexOf(aSink));
end;

function TGDirectInt64Net.GetNetworkStateI(aSrcIdx, aSinkIdx: SizeInt): TNetworkState;
var
  Queue: TIntArray;
  Visited: TBoolVector;
  Curr: SizeInt;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
  SinkFound: Boolean = False;
begin
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aSinkIdx);
  if VertexCount < 2 then
    exit(nsTrivial);
  if not IsSourceI(aSrcIdx) then
    exit(nsInvalidSource);
  if not IsSinkI(aSinkIdx) then
    exit(nsInvalidSink);
  Queue := CreateIntArray;
  Visited.Capacity := VertexCount;
  Visited.UncBits[aSrcIdx] := True;
  Queue[qTail] := aSrcIdx;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := Queue[qHead];
      Inc(qHead);
      for p in AdjLists[Curr]^ do
        begin
          if p^.Data.Weight < 0 then // network can not contain arcs with negative capacity
            exit(nsNegCapacity);
          if not Visited.UncBits[p^.Destination] and (p^.Data.Weight > 0) then
            begin
              Queue[qTail] := p^.Destination;
              Inc(qTail);
              Visited.UncBits[p^.Destination] := True;
              SinkFound := SinkFound or (p^.Destination = aSinkIdx);
            end;
        end;
    end;
  if not SinkFound then // sink must be reachable from the source
    exit(nsSinkUnreachable);
  Result := nsOk;
end;

function TGDirectInt64Net.FindMaxFlowPr(const aSource, aSink: TVertex; out aFlow: TWeight): TNetworkState;
begin
  Result := FindMaxFlowPrI(IndexOf(aSource), IndexOf(aSink), aFlow);
end;

function TGDirectInt64Net.FindMaxFlowPrI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight): TNetworkState;
var
  Helper: THPrHelper;
begin
  aFlow := 0;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result = nsOk then
    aFlow := Helper.GetMaxFlow(Self, aSrcIdx, aSinkIdx);
end;

function TGDirectInt64Net.FindMaxFlowPr(const aSource, aSink: TVertex; out aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
begin
  Result := FindMaxFlowPrI(IndexOf(aSource), IndexOf(aSink), aFlow, a);
end;

function TGDirectInt64Net.FindMaxFlowPrI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
var
  Helper: THPrHelper;
begin
  aFlow := 0;
  a := nil;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result = nsOk then
    aFlow := Helper.GetMaxFlow(Self, aSrcIdx, aSinkIdx, a);
end;

function TGDirectInt64Net.FindFlowPr(const aSource, aSink: TVertex; var aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
begin
  Result := FindFlowPrI(IndexOf(aSource), IndexOf(aSink), aFlow, a);
end;

function TGDirectInt64Net.FindFlowPrI(aSrcIdx, aSinkIdx: SizeInt; var aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
var
  Helper: THPrHelper;
begin
  a := nil;
  if aFlow < 0 then
    aFlow := 0;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if (Result = nsOk) and (aFlow > 0) then
    aFlow := Helper.GetFlow(Self, aSrcIdx, aSinkIdx, aFlow, a);
end;

function TGDirectInt64Net.FindMaxFlowD(const aSource, aSink: TVertex; out aFlow: TWeight): TNetworkState;
begin
  Result := FindMaxFlowDI(IndexOf(aSource), IndexOf(aSink), aFlow);
end;

function TGDirectInt64Net.FindMaxFlowDI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight): TNetworkState;
var
  Helper: TDinitzHelper;
begin
  aFlow := 0;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result = nsOk then
    aFlow := Helper.GetMaxFlow(Self, aSrcIdx, aSinkIdx);
end;

function TGDirectInt64Net.FindMaxFlowD(const aSource, aSink: TVertex; out aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
begin
  Result := FindMaxFlowDI(IndexOf(aSource), IndexOf(aSink), aFlow, a);
end;

function TGDirectInt64Net.FindMaxFlowDI(aSrcIdx, aSinkIdx: SizeInt; out aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
var
  Helper: TDinitzHelper;
begin
  aFlow := 0;
  a := nil;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result = nsOk then
    aFlow := Helper.GetMaxFlow(Self, aSrcIdx, aSinkIdx, a);
end;

function TGDirectInt64Net.FindFlowD(const aSource, aSink: TVertex; var aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
begin
  Result := FindFlowDI(IndexOf(aSource), IndexOf(aSink), aFlow, a);
end;

function TGDirectInt64Net.FindFlowDI(aSrcIdx, aSinkIdx: SizeInt; var aFlow: TWeight;
  out a: TEdgeArray): TNetworkState;
var
  Helper: TDinitzHelper;
begin
  a := nil;
  if aFlow < 0 then
    aFlow := 0;
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if (Result = nsOk) and (aFlow > 0) then
    aFlow := Helper.GetFlow(Self, aSrcIdx, aSinkIdx, aFlow, a);
end;

function TGDirectInt64Net.IsFeasibleFlow(const aSource, aSink: TVertex; aFlow: TWeight;
  const a: TEdgeArray): Boolean;
begin
  Result := IsFeasibleFlowI(IndexOf(aSource), IndexOf(aSink), aFlow, a);
end;

function TGDirectInt64Net.IsFeasibleFlowI(aSrcIdx, aSinkIdx: SizeInt; aFlow: TWeight;
  const a: TEdgeArray): Boolean;
var
  v: array of TWeight;
  e: TWeightEdge;
  d: TEdgeData;
  I: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aSinkIdx);
  if System.Length(a) <> EdgeCount then
    exit(False);
  v := TWeightHelper.CreateWeightArrayZ(VertexCount);
  v[aSrcIdx] += aFlow;
  v[aSinkIdx] -= aFlow;
  for e in a do
    begin
      if not GetEdgeDataI(e.Source, e.Destination, d) then
        exit(False);
      if e.Weight > d.Weight then
        exit(False);
      v[e.Source] -= e.Weight;
      v[e.Destination] += e.Weight;
    end;
  for I := 0 to System.High(v) do
    if v[I] <> 0 then
      exit(False);
  Result := True;
end;

function TGDirectInt64Net.FindMinSTCutPr(const aSource, aSink: TVertex; out aValue: TWeight;
  out aCut: TStCut): TNetworkState;
begin
  Result := FindMinSTCutPrI(IndexOf(aSource), IndexOf(aSink), aValue, aCut);
end;

function TGDirectInt64Net.FindMinSTCutPrI(aSrcIdx, aSinkIdx: SizeInt; out aValue: TWeight;
  out aCut: TStCut): TNetworkState;
var
  Helper: THPrHelper;
  TmpSet: TBoolVector;
  I: SizeInt;
begin
  aValue := 0;
  aCut.S := nil;
  aCut.T := nil;
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aSinkIdx);
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result <> nsOk then
    exit;
  aValue := Helper.GetMinCut(Self, aSrcIdx, aSinkIdx, aCut.S);
  TmpSet.InitRange(VertexCount);
  for I in aCut.S do
    TmpSet.UncBits[I] := False;
  aCut.T := TmpSet.ToArray;
end;

function TGDirectInt64Net.FindMinSTCutD(const aSource, aSink: TVertex; out aValue: TWeight;
  out aCut: TStCut): TNetworkState;
begin
  Result := FindMinSTCutDI(IndexOf(aSource), IndexOf(aSink), aValue, aCut);
end;

function TGDirectInt64Net.FindMinSTCutDI(aSrcIdx, aSinkIdx: SizeInt; out aValue: TWeight;
  out aCut: TStCut): TNetworkState;
var
  Helper: TDinitzHelper;
  TmpSet: TBoolVector;
  I: SizeInt;
begin
  aValue := 0;
  aCut.S := [];
  aCut.T := [];
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aSinkIdx);
  Result := GetNetworkStateI(aSrcIdx, aSinkIdx);
  if Result <> nsOk then
    exit;
  aValue := Helper.GetMinCut(Self, aSrcIdx, aSinkIdx, aCut.S);
  TmpSet.InitRange(VertexCount);
  for I in aCut.S do
    TmpSet.UncBits[I] := False;
  aCut.T := TmpSet.ToArray;
end;

{ TCostPair }

constructor TCostPair.Create(aWeight: Int64; aCost: TCost);
begin
  Weight := aWeight;
  Cost := aCost;
end;

{$I Mcf.inc}

function TGCostedInt64Net.Clone: TGCostedInt64Net;
begin
  Result := TGCostedInt64Net.Create;
  Result.AssignGraph(Self);
end;

function TGCostedInt64Net.Reverse: TGCostedInt64Net;
begin
  Result := TGCostedInt64Net.Create;
  Result.AssignReverse(Self);
end;

function TGCostedInt64Net.InducedSubgraph(const aVertexList: TIntArray): TGCostedInt64Net;
begin
  Result := TGCostedInt64Net.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGCostedInt64Net.FindMinCostFlowSsp(const aSource, aSink: TVertex; var aReqFlow: TWeight;
  out aTotalCost: TCost): TMcfState;
begin
  Result := FindMinCostFlowSspI(IndexOf(aSource), IndexOf(aSink), aReqFlow, aTotalCost);
end;

function TGCostedInt64Net.FindMinCostFlowSspI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
  out aTotalCost: TCost): TMcfState;
var
  Helper: TSspMcfHelper;
begin
  aTotalCost := 0;
  if aReqFlow < 1 then
    exit(mcfNoFlowRequired);
  if GetNetworkStateI(aSrcIdx, aSinkIdx) <> nsOk then
    exit(mcfInvalidNet);
  aReqFlow := Helper.GetMinCostFlow(Self, aSrcIdx, aSinkIdx, aReqFlow, aTotalCost);
  if aReqFlow = 0 then
    exit(mcfNegCycle);
  Result := mcfOk;
end;

function TGCostedInt64Net.FindMinCostFlowSsp(const aSource, aSink: TVertex; var aReqFlow: TWeight;
  out aTotalCost: TCost; out aArcFlows: TEdgeArray): TMcfState;
begin
  Result := FindMinCostFlowSspI(IndexOf(aSource), IndexOf(aSink), aReqFlow, aTotalCost, aArcFlows);
end;

function TGCostedInt64Net.FindMinCostFlowSspI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
  out aTotalCost: TCost; out aArcFlows: TEdgeArray): TMcfState;
var
  Helper: TSspMcfHelper;
begin
  aTotalCost := 0;
  aArcFlows := nil;
  if aReqFlow < 1 then
    exit(mcfNoFlowRequired);
  if GetNetworkStateI(aSrcIdx, aSinkIdx) <> nsOk then
    exit(mcfInvalidNet);
  aReqFlow := Helper.GetMinCostFlow(Self, aSrcIdx, aSinkIdx, aReqFlow, aTotalCost, aArcFlows);
  if aReqFlow = 0 then
    exit(mcfNegCycle);
  Result := mcfOk;
end;

function TGCostedInt64Net.FindMinCostFlowCs(const aSource, aSink: TVertex; var aReqFlow: TWeight;
  out aTotalCost: TCost): TMcfState;
begin
  Result := FindMinCostFlowCsI(IndexOf(aSource), IndexOf(aSink), aReqFlow, aTotalCost);
end;

function TGCostedInt64Net.FindMinCostFlowCsI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
  out aTotalCost: TCost): TMcfState;
var
  Helper: TCsMcfHelper;
begin
  aTotalCost := 0;
  if aReqFlow < 1 then
    exit(mcfNoFlowRequired);
  if GetNetworkStateI(aSrcIdx, aSinkIdx) <> nsOk then
    exit(mcfInvalidNet);
  aReqFlow := Helper.GetMinCostFlow(Self, aSrcIdx, aSinkIdx, aReqFlow, aTotalCost);
  if aReqFlow = 0 then
    exit(mcfNegCycle);
  Result := mcfOk;
end;

function TGCostedInt64Net.FindMinCostFlowCs(const aSource, aSink: TVertex; var aReqFlow: TWeight;
  out aTotalCost: TCost; out aArcFlows: TEdgeArray): TMcfState;
begin
  Result := FindMinCostFlowCsI(IndexOf(aSource), IndexOf(aSink), aReqFlow, aTotalCost, aArcFlows);
end;

function TGCostedInt64Net.FindMinCostFlowCsI(aSrcIdx, aSinkIdx: SizeInt; var aReqFlow: TWeight;
  out aTotalCost: TCost; out aArcFlows: TEdgeArray): TMcfState;
var
  Helper: TCsMcfHelper;
begin
  aTotalCost := 0;
  aArcFlows := nil;
  if aReqFlow < 1 then
    exit(mcfNoFlowRequired);
  if GetNetworkStateI(aSrcIdx, aSinkIdx) <> nsOk then
    exit(mcfInvalidNet);
  aReqFlow := Helper.GetMinCostFlow(Self, aSrcIdx, aSinkIdx, aReqFlow, aTotalCost, aArcFlows);
  if aReqFlow = 0 then
    exit(mcfNegCycle);
  Result := mcfOk;
end;

function TGCostedInt64Net.IsMcfFeasible(const aSource, aSink: TVertex; const aArcFlows: TEdgeArray;
  aFlow: TWeight; aTotalCost: TCost): Boolean;
begin
  Result := IsMcfFeasibleI(IndexOf(aSource), IndexOf(aSink), aArcFlows, aFlow, aTotalCost);
end;

function TGCostedInt64Net.IsMcfFeasibleI(aSrcIdx, aSinkIdx: SizeInt; const aArcFlows: TEdgeArray;
  aFlow: TWeight; aTotalCost: TCost): Boolean;
var
  v: array of TWeight;
  e: TWeightEdge;
  d: TEdgeData;
  Cost: TCost;
  I: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aSinkIdx);
  if System.Length(aArcFlows) <> EdgeCount then
    exit(False);
  v := TWeightHelper.CreateWeightArrayZ(VertexCount);
  v[aSrcIdx] += aFlow;
  v[aSinkIdx] -= aFlow;
  Cost := 0;
  for e in aArcFlows do
    begin
      if not GetEdgeDataI(e.Source, e.Destination, d) then
        exit(False);
      if e.Weight > d.Weight then
        exit(False);
      v[e.Source] -= e.Weight;
      v[e.Destination] += e.Weight;
      Cost += e.Weight * d.Cost;
    end;
  for I := 0 to System.High(v) do
    if v[I] <> 0 then
      exit(False);
  Result := Cost = aTotalCost;
end;

end.

