{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic simple undirected graphs implementation.                        *
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
unit lgSimpleGraph;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}
{$MODESWITCH ARRAYOPERATORS}

interface

uses
  Classes, SysUtils, DateUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgArrayHelpers,
  lgStack,
  lgVector,
  lgQueue,
  lgSparseGraph,
  lgStrHelpers,
  lgMiscUtils,
  lgStrConst;

type
  TLineGraph = class; //forward declaration

  { TGSimpleGraph implements simple sparse undirected graph based on adjacency lists;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGSimpleGraph<TVertex, TEdgeData, TEqRel> = class(
    specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>)
  public
  type
    {TPlanarEmbedding: representation of a combinatorial embedding }
    TPlanarEmbedding = record
    private
    const
      DEFAUL_INCREMENT = 2;
      TYPE_NAME        = 'TPlanarEmbedding';
    type
      THalfEdge = record
        Source,
        Target,
        Prev,
        Next: SizeInt;
      end;

      THalfEdgeList = array of THalfEdge;

      TAdjCwEnumerator = record
      private
        FList: THalfEdgeList;
        CurrEdge,
        FirstEdge: SizeInt;
        function  GetCurrent: SizeInt; inline;
      public
        function  MoveNext: Boolean;
        property  Current: SizeInt read GetCurrent;
      end;

      TEdgeEnumerator = record
      private
        FList: THalfEdgeList;
        CurrEdge: SizeInt;
        function  GetCurrent: TIntEdge; inline;
      public
        function  MoveNext: Boolean; inline;
        property  Current: TIntEdge read GetCurrent;
      end;

    var
      FEdgeList: THalfEdgeList;
      FNodeList: TIntArray;
      FComponents: TIntVectorArray;
      FCounter: SizeInt;
      function  GetNodeCount: SizeInt; inline;
      function  GetEdgeCount: SizeInt; inline;
      function  GetCompCount: SizeInt; inline;
      function  GetCompPop(aIndex: SizeInt): SizeInt;
      function  GetComponent(aIndex: SizeInt): TIntArray;
      procedure Init(aNodeCount, aEdgeCount, aCompCount: SizeInt);
      procedure Init1;
      procedure Init2(aConn: Boolean);
      function  CreateEdge(aSrc, aDst: SizeInt): SizeInt;
      function  GetReverse(aEdge: SizeInt): SizeInt; inline;
      function  AddEdge(aSrc, aDst: SizeInt): SizeInt;
      procedure InsertFirst(aEdge: SizeInt);
      procedure InsertAfter(aEdge, aRef: SizeInt);
      procedure InsertBefore(aEdge, aRef: SizeInt);
      function  FindEdge(aSrc, aDst: SizeInt): SizeInt;
      function  NextFaceEdge(aEdgeIdx: SizeInt): SizeInt;
    public
    type
      TAdjListCw = record
      private
        List: THalfEdgeList;
        FirstEdge: SizeInt;
      public
        function GetEnumerator: TAdjCwEnumerator; inline;
      end;

      TEdges = record
      private
        FList: THalfEdgeList;
      public
        function GetEnumerator: TEdgeEnumerator; inline;
      end;

      function IsEmpty: Boolean; inline;
      function AdjListCw(aNode: SizeInt): TAdjListCw;
      function Edges: TEdges; inline;
      function ContainsEdge(aSrc, aDst: SizeInt): Boolean; inline;
      function ContainsEdge(constref aEdge: TIntEdge): Boolean; inline;
      function FindFirstEdge(aNode: SizeInt; out aEdge: TIntEdge): Boolean;
      function NextFaceEdge(constref aEdge: TIntEdge): TIntEdge;
      function TraverseFace(constref aEdge: TIntEdge; aOnPassEdge: TOnPassEdge = nil): TIntArray;
      function TraverseFace(constref aEdge: TIntEdge; aOnPassEdge: TNestPassEdge): TIntArray;
      property NodeCount: SizeInt read GetNodeCount;
      property EdgeCount: SizeInt read GetEdgeCount;
      property ComponentCount: SizeInt read GetCompCount;
      property ComponentPop[aIndex: SizeInt]: SizeInt read GetCompPop;
      property Components[aIndex: SizeInt]: TIntArray read GetComponent; default;
    end;

  protected
  type
    TSortByDegreeHelper = specialize TGDelegatedArrayHelper<SizeInt>;
    TSpecNodeDone       = procedure(aNodeIndex: SizeInt; const aLefts: TIntSet) is nested;

    {$I SimpGraphHelpH.inc}

    TDistinctEdgeEnumerator = record
    private
      FList: PNode;
      FEnum: TAdjList.TEnumerator;
      FCurrIndex,
      FLastIndex: SizeInt;
      FEnumDone: Boolean;
      function  GetCurrent: TEdge;
    public
      function  MoveNext: Boolean;
      procedure Reset;
      property  Current: TEdge read GetCurrent;
    end;

    TDistinctEdges = record
      private
        FGraph: TGSimpleGraph;
      public
        function GetEnumerator: TDistinctEdgeEnumerator;
    end;

  const
    LISTCLIQUES_BP_CUTOFF       = 60000; //BP: bit-parallel
    COMMON_BP_CUTOFF            = 50000;
    MAXCLIQUE_BP_DENSITY_CUTOFF = 0.005;

  protected
    FCompCount: SizeInt;
    FConnected,
    FConnectedValid: Boolean;
    procedure ResetTags;
    function  SeparateTag(aIndex: SizeInt): SizeInt;
    function  SeparateJoin(L, R: SizeInt): Boolean;
    procedure ValidateConnected;
    function  GetConnected: Boolean; //inline;
    function  GetDensity: Double; inline;
    function  CreateSkeleton: TSkeleton;
    procedure AssignGraph(aGraph: TGSimpleGraph);
    procedure AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
    procedure AssignPermutation(aGraph: TGSimpleGraph; const aMap: TIntArray);
    function  GetSeparateCount: SizeInt;
    function  CountPop(aTag: SizeInt): SizeInt;
    function  MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
    function  CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
    function  CheckAcyclic: Boolean;
  { returns True if there exists a perfect elimination order in the graph;
    in this case returns this order (reverse) in aOrd and max clique in aClique }
    function  FindPerfectElimOrd(aOnNodeDone: TSpecNodeDone; out aPeoSeq: TIntArray): Boolean;
    function  FindChordalMaxClique(out aClique: TIntSet): Boolean;
    function  FindChordalMis(out aMis: TIntSet): Boolean;
    function  FindChordalColoring(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
    function  GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxCliqueConnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxCliqueDisconnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GreedyMatching: TIntEdgeArray;
    function  GreedyMatching2: TIntEdgeArray;
    procedure ListCliquesBP(aOnFind: TOnSetFound);
    procedure ListCliquesBP256(aOnFind: TOnSetFound);
    procedure ListCliques(aOnFind: TOnSetFound);
  { returns max independent set in the bipartite graph }
    function  GetMisBipartite(const w, g: TIntArray): TIntArray;
    function  GetMisBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMisBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMisConnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMisDisconnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure ListIsBP(aOnFind: TOnSetFound);
    procedure ListIsBP256(aOnFind: TOnSetFound);
    function  GetGreedyMis: TIntArray;
    function  GetGreedyMisBP: TIntArray;
    function  GetGreedyMinIs: TIntArray;
    function  GetGreedyMinIsBP: TIntArray;
    procedure DoListDomSets(aMaxSize: SizeInt; aOnFind: TOnSetFound);
    function  GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  ColorTrivial(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
    function  ColorConnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
    function  ColorDisconnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
    function  ColorableConnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
    function  ColorableDisconnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
    function  GreedyColorRlf(out aColors: TIntArray): SizeInt;
    function  GreedyColor(out aColors: TIntArray): SizeInt;
    procedure SearchForCutVertices(aRoot: SizeInt; var aPoints: TIntHashSet);
    function  CutVertexExists(aRoot: SizeInt): Boolean;
    procedure SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
    procedure SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
    function  BridgeExists: Boolean;
    procedure SearchForBridges(var aBridges: TIntEdgeVector);
    procedure SearchForCycleBasis(out aCycles: TIntArrayVector);
    procedure SearchForCycleBasisVector(out aVector: TIntVector);
  { finds some system of fundamental cycles and returns their length vector,
    sorted in non-descending order}
    function  GetCycleBasisVector: TIntArray;
    function  CreateDegreeVector: TIntArray;
  { may raise integer overflow }
    function  CreateNeighDegreeVector: TIntArray;
    function  CreateComplementDegreeArray: TIntArray;
    function  SortNodesByWidth(o: TSortOrder): TIntArray;
    function  SortComplementByWidth: TIntArray;
    function  SortNodesByDegree(o: TSortOrder): TIntArray;
    function  CmpByDegree(const L, R: SizeInt): Boolean;
    function  CmpIntArrayLen(const L, R: TIntArray): Boolean;
    function  DoAddVertex(const aVertex: TVertex; out aIndex: SizeInt): Boolean; override;
    procedure DoRemoveVertex(aIndex: SizeInt); override;
    function  DoAddEdge(aSrc, aDst: SizeInt; const aData: TEdgeData): Boolean; override;
    function  DoRemoveEdge(aSrc, aDst: SizeInt): Boolean; override;
    function  DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeData): Boolean; override;
    procedure DoWriteEdges(aStream: TStream; aOnWriteData: TOnWriteData); override;
    procedure EdgeContracting(aSrc, aDst: SizeInt); override;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function MayBeIsomorphic(L, R: TGSimpleGraph): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    constructor Create;
    procedure Clear; override;
  { returns copy of the source graph }
    function  Clone: TGSimpleGraph;
  { returns graph of connected component that contains aVertex }
    function  SeparateGraph(const aVertex: TVertex): TGSimpleGraph; //todo: CreateSeparateGraph ???
    function  SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
  { returns a subgraph induced by the vertices whose indices are contained in the array aVertexList }
    function  InducedSubgraph(const aVertexList: TIntArray): TGSimpleGraph;
  { returns a subgraph constructed the pairs provided by the aTree,
    i.e. each element treates as pair of source - destination(value -> source, index -> destination ) }
    function  SubgraphFromTree(const aTree: TIntArray): TGSimpleGraph;
  { returns a graph constructed from the edges provided by the aEdges }
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TGSimpleGraph;
  { }
    function  CreatePermutation(const aMap: TIntArray): TGSimpleGraph;
  { returns line graph constucted from self }
    function  CreateLineGraph: TLineGraph;
  { symmetric difference }
    procedure SetSymmDifferenceOf(aGraph: TGSimpleGraph);
{**********************************************************************************************************
  structural management utilities
***********************************************************************************************************}

    function  Degree(const aVertex: TVertex): SizeInt; inline;
    function  DegreeI(aIndex: SizeInt): SizeInt;
    function  Isolated(const aVertex: TVertex): Boolean; inline;
    function  IsolatedI(aIndex: SizeInt): Boolean; inline;
    function  DistinctEdges: TDistinctEdges;
  { returns adjacency matrix of the complement graph;
    warning: maximum matrix size limited, see BitMatrixSizeMax }
    function  CreateComplementMatrix: TAdjacencyMatrix;
  { if the graph is not empty, then make graph connected, adding, if necessary, new edges
    from the vertex with the index 0; returns count of added edges;
    if aOnAddEdge = nil then new edges will use default data value }
    function  EnsureConnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
  { checks whether the aDst reachable from the aSrc; each vertex reachable from itself  }
    function  PathExists(const aSrc, aDst: TVertex): Boolean; inline;
    function  PathExistsI(aSrc, aDst: SizeInt): Boolean;
  { returns number of vertices(population) in the connected component that contains aVertex }
    function  SeparatePop(const aVertex: TVertex): SizeInt; inline;
    function  SeparatePopI(aIndex: SizeInt): SizeInt;
  { returns array of indices of the connected component that contains aVertex }
    function  GetSeparate(const aVertex: TVertex): TIntArray; inline;
    function  GetSeparateI(aIndex: SizeInt): TIntArray;
  { returns in the result array the vectors of indices of all connected components }
    function  FindSeparates: TIntVectorArray;
    function  IsTree: Boolean;
    function  IsStar(out aHub: SizeInt): Boolean;
    function  IsCycle: Boolean;
    function  IsWheel(out aHub: SizeInt): Boolean;
    function  IsComplete: Boolean;
  { checks whether the graph is regular(that is, the degrees of all its vertices are equal);
    an empty graph is considered regular }
    function  IsRegular(out aDegree: SizeInt): Boolean;
  { returns True and the list of vertex indices in the perfect elimination order(reverse)
    in aRevPeo, if graph is chordal, otherwise returns False and nil;
    an empty graph is considered chordal }
    function  IsChordal(out aRevPeo: TIntArray): Boolean;
  { returns True if graph is planar, an empty graph is considered planar;
    used FMR Left-Right planarity algorithm }
    function  IsPlanar: Boolean;
  { same as above, recursive variant }
    function  IsPlanarR: Boolean;
  { returns True and the planar embedding in aEmbedding, if graph is planar,
    otherwise returns False and nil; used FMR Left-Right planarity algorithm;
    todo: Kuratowski subdivision extraction? }
    function  IsPlanar(out aEmbedding: TPlanarEmbedding): Boolean;
  { same as above, recursive variant }
    function  IsPlanarR(out aEmbedding: TPlanarEmbedding): Boolean;
  { returns True if aEmbedding is proper planar embedding }
    function  IsEmbedding(const aEmbedding: TPlanarEmbedding): Boolean;
  { returns degeneracy of graph, -1 if graph is empty;
    the degeneracy of a graph G is the least k, such that every induced subgraph of G contains
    a vertex with degree d <= k }
    function  Degeneracy: SizeInt;
  { same as above and in array aCores returns the degrees of the corresponding vertices,
    such that if aDegs[I] = k, then vertex I belongs to the k-core and not to the (k+1)-core }
    function  Degeneracy(out aDegs: TIntArray): SizeInt;
  { returns array of indices of the k-core(k-cores if graph is not connected) }
    function  KCore(aK: SizeInt): TIntArray;
  { returns local clustering coefficient of the aVertex: how close its neighbours are to being a clique }
    function  LocalClustering(const aVertex: TVertex): ValReal; inline;
    function  LocalClusteringI(aIndex: SizeInt): Double;
  { returns count of independent cycles }
    function  CyclomaticNumber: SizeInt;
  { returns True if exists any cycle in the aVertex connected component,
    in this case aCycle will contain indices of the vertices of the found cycle }
    function  ContainsCycle(const aVertex: TVertex; out aCycle: TIntArray): Boolean; inline;
    function  ContainsCycleI(aIndex: SizeInt; out aCycle: TIntArray): Boolean;
  { checks whether the graph is acyclic; an empty graph is considered acyclic }
    function  IsAcyclic: Boolean;
  { checks whether exists Eulerian path; if exists only path, then
    aFirstOdd will contains index of first vertex with odd degree, otherwise -1 }
    function  ContainsEulerianPath(out aFirstOdd: SizeInt): Boolean;
  { checks whether exists Eulerian cycle }
    function  ContainsEulerianCycle: Boolean;
  { looking for some Eulerian cycle in the connected component }
    function  FindEulerianCycle: TIntArray;
  { looking for some Eulerian path in the connected component }
    function  FindEulerianPath: TIntArray;
  { finds a certain system of fundamental cycles }
    function  FindFundamentalCycles: TIntArrayVector;
  { checks whether exists any articulation point that belong to the aVertex connected component }
    function  ContainsCutVertex(const aVertex: TVertex): Boolean; inline;
    function  ContainsCutVertexI(aIndex: SizeInt): Boolean;
  { returns the articulation points that belong to the aVertex connection component, if any,
    otherwise the empty vector }
    function  FindCutVertices(const aVertex: TVertex): TIntArray; inline;
    function  FindCutVerticesI(aIndex: SizeInt): TIntArray;
  { removes the articulation points that belong to the aVertex connected component, adding,
    if necessary, new edges; returns count of added edges;
    if aOnAddEdge is nil then new edges will use default data value }
    function  RemoveCutVertices(const aVertex: TVertex; aOnAddEdge: TOnAddEdge = nil): SizeInt; inline;
    function  RemoveCutVerticesI(aIndex: SizeInt; aOnAddEdge: TOnAddEdge = nil): SizeInt;
  { checks whether exists any bridge in graph }
    function  ContainsBridge: Boolean;
  { returns all bridges in the result vector, if any, otherwise the empty vector }
    function  FindBridges: TIntEdgeArray;
  { checks whether the graph is biconnected; graph with single vertex is considered biconnected }
    function  IsBiconnected: Boolean; inline;
  { returns a vector containing in the corresponding elements the edges
    of found bicomponents (in aVertex connected component) in aComps }
    procedure FindBicomponents(const aVertex: TVertex; out aComps: TEdgeArrayVector);
    procedure FindBicomponentsI(aIndex: SizeInt; out aComps: TEdgeArrayVector);
  { if the graph is not empty, then make graph biconnected, adding, if necessary, new edges;
    returns count of added edges; if aOnAddEdge is nil then new edges will use default data value }
    function  EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
  { returns True, radius and diameter, if graph is connected, False otherwise }
    function  FindMetrics(out aRadius, aDiameter: SizeInt): Boolean;
  { returns array of indices of the central vertices, if graph is connected, nil otherwise }
    function  FindCenter: TIntArray;
  { returns array of indices of the peripheral vertices, if graph is connected, nil otherwise }
    function  FindPeripheral: TIntArray;
  { returns an array containing a chain of vertex indices of the found shortest(in the sense of "number of edges")
    path, or an empty array if the path does not exists }
    function ShortestPath(const aSrc, aDst: TVertex): TIntArray; inline;
    function ShortestPathI(aSrc, aDst: SizeInt): TIntArray;
    type
      //vertex partition
      TCut = record
        A,
        B: TIntArray;
      end;

  { returns size of the some global minimum cut; used Nagamochi-Ibaraki algorithm }
    function  MinCut: SizeInt;
    function  MinCut(out aCut: TCut): SizeInt;
  { same as above and additionally in aCrossEdges returns array of the edges that cross the minimum cut }
    function  MinCut(out aCut: TCut; out aCrossEdges: TIntEdgeArray): SizeInt;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality, used Hopcroft–Karp algorithm with recursive DFS }
    function FindMaxBipMatchHK(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function GetMaxBipMatchHK(const aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality }
    function FindMaxBipMatchBfs(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function GetMaxBipMatchBfs(const aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns the approximation of the matching of the maximum cardinality in an arbitrary graph }
    function GreedyMaxMatch: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Edmonds(?) algorithm }
    function FindMaxMatchEd: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Pape-Conradt algorithm }
    function FindMaxMatchPC: TIntEdgeArray;
{**********************************************************************************************************
  some NP-hard problem utilities
***********************************************************************************************************}

  { lists all maximal independent vertex sets; will raise an exception if aOnFound is not assigned;
    setting aCancel to True in aOnFound will exit the method }
    procedure ListAllMIS(aOnFound: TOnSetFound);
  { returns indices of the vertices of the some found maximum independent set;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout the best recent solution will be returned, and aExact
    will be set to False }
    function  FindMIS(out aExact: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMIS: TIntArray;
  { returns True if aTestMis contains indices of the some maximal independent vertex set, False otherwise }
    function  IsMIS(const aTestMis: TIntArray): Boolean;
  { lists all the dominating vertex sets(not necessary minimal) with the number
    of elements at most AtMostSize; will raise an exception if aOnFound is not assigned;
    setting aCancel to True in aOnFound will exit the method }
    procedure ListDomSets(AtMostSize: SizeInt; aOnFound: TOnSetFound);
  { returns indices of the vertices of the some found minimum dominating vertex set;
    worst case time cost of exact solution O*(2^n);
    aTimeOut specifies the timeout in seconds; at the end of the timeout the best
    recent solution will be returned, and aExact will be set to False }
    function  FindMDS(out aExact: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMDS: TIntArray;
  { returns True if aTestMds contains indices of the some minimal dominating vertex set, False otherwise }
    function  IsMDS(const aTestMds: TIntArray): Boolean;
  { lists all maximal cliques; will raise an exception if aOnFound is not assigned;
    setting aCancel to True in aOnFound will exit the method }
    procedure ListAllCliques(aOnFound: TOnSetFound);
  { returns indices of the vertices of the some found maximum clique;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout the best recent solution will be returned, and aExact
    will be set to False }
    function  FindMaxClique(out aExact: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMaxClique: TIntArray;
  { returns True if aTestClique contains indices of the some maximal clique, False otherwise }
    function  IsMaxClique(const aTestClique: TIntArray): Boolean;
  { lists all minimal vertex covers; will raise an exception if aOnFound is not assigned;
    setting aCancel to True in aOnFound will exit the method }
    procedure ListAllMVC(aOnFound: TOnSetFound);
  { returns indices of the vertices of the some found minimum vertex cover;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout the best recent solution will be returned, and aExact
    will be set to False }
    function  FindMVC(out aExact: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMVC: TIntArray;
  { returns True if aTestMvc contains indices of the some minimal vertex cover, False otherwise }
    function  IsMVC(const aTestMvc: TIntArray): Boolean;
  { returns count of used colors(chromatic number, if aExact); returns colors of the vertices
    in corresponding components of aColors; worst case time cost of exact solution O*(k^n);
    aTimeOut specifies the timeout in seconds; at the end of the timeout,
    the best recent solution will be returned, and aExact will be set to False }
    function  VertexColoring(out aColors: TIntArray; out aExact: Boolean;
              aTimeOut: Integer = WAIT_INFINITE): SizeInt;
  { returns tlTrue and colors of the vertices in corresponding components of aColors,
    if exist the vertex coloring which uses at most aK of colors;
    aTimeOut specifies the timeout in seconds; at the end of the timeout tlUnknown will be returned }
    function  IsKColorable(aK: SizeInt; out aColors: TIntArray; aTimeOut: Integer = WAIT_INFINITE): TTriLean;
  { returns tlTrue if it is possible to complete the coloring using predefined colors specified
    in aColors and at most aK of colors; aTimeOut specifies the timeout in seconds;
    at the end of the timeout tlUnknown will be returned }
    function  IsKColorCompletable(aK: SizeInt; var aColors: TIntArray;
              aTimeOut: Integer = WAIT_INFINITE): TTriLean;
  { returns count of colors; returns colors of the vertices in corresponding components of aColors;
    used RLF greedy coloring algorithm }
    function  GreedyVertexColoringRlf(out aColors: TIntArray): SizeInt;
  { returns count of colors; returns colors of the vertices in corresponding components of aColors(GIS ?) }
    function  GreedyVertexColoring(out aColors: TIntArray): SizeInt;
  { returns True if aTestColors is complete and proper coloring of the vertices, False otherwise }
    function  IsProperVertexColoring(const aTestColors: TIntArray): Boolean;
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
  { tries to return in aPaths the specified number of Hamiltonian paths, starting
    from the vertex aSrc; if aCount <= 0, then all paths are returned;
    if aCount > 0, then Min(aCount, total) cycles are returned; aTimeOut specifies
    the timeout in seconds; at the end of the timeout False will be returned }
    function  FindHamiltonPaths(const aSource: TVertex; aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean; inline;
    function  FindHamiltonPathsI(aSourceIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns True if aTestPath is Hamiltonian path starting from the vertex with index aSourceIdx }
    function  IsHamiltonPath(const aTestPath: TIntArray; aSourceIdx: SizeInt): Boolean;
{**********************************************************************************************************
  properties
***********************************************************************************************************}

  { checks whether the cached info about connected is up-to-date }
    property  ConnectedValid: Boolean read FConnectedValid;
  { checks whether the graph is connected; an empty graph is considered disconnected }
    property  Connected: Boolean read GetConnected;
  { count of connected components }
    property  SeparateCount: SizeInt read GetSeparateCount;
    property  Density: Double read GetDensity;
  end;

  TLineGraph = class(specialize TGSimpleGraph<TOrdIntPair, TIntValue, TOrdIntPair>);

  { TGSimpleObjGraph }
  generic TGSimpleObjGraph<TVertexClass, TEdgeClass, TEqRel> = class(
    specialize TGSimpleGraph<TVertexClass, TEdgeClass, TEqRel>)
  private
    FOwnsVerts,
    FOwnsEdges: Boolean;
    procedure ClearObjects;
  protected
    procedure VertexReplaced(const v: TVertexClass); override;
    procedure DoRemoveVertex(aIndex: SizeInt); override;
    function  DoRemoveEdge(aSrc, aDst: SizeInt): Boolean; override;
    function  DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeClass): Boolean; override;
  public
  type
    TObjectOwns   = (ooOwnsVertices, ooOwnsEdges);
    TObjOwnership = set of TObjectOwns;
    constructor Create(aOwns: TObjOwnership = [ooOwnsVertices, ooOwnsEdges]);
    destructor  Destroy; override;
    procedure Clear; override;
    property  OwnsVertices: Boolean read FOwnsVerts write FOwnsVerts;
    property  OwnsEdges: Boolean read FOwnsEdges write FOwnsEdges;
  end;

  { TGChart: simple outline;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGChart<TVertex, TEqRel> = class(specialize TGSimpleGraph<TVertex, TDummy, TEqRel>)
  private
    procedure ReadData(aStream: TStream; out aValue: TDummy);
    procedure WriteData(aStream: TStream; const aValue: TDummy);
  public
    function  SeparateGraph(const aVertex: TVertex): TGChart;
    function  SeparateGraphI(aIndex: SizeInt): TGChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TGChart;
    function  SubgraphFromTree(const aTree: TIntArray): TGChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TGChart;
    function  CreatePermutation(const aMap: TIntArray): TGChart;
    function  Clone: TGChart;
    procedure SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
    procedure SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
    procedure SetUnionOf(aChart: TGChart);
    procedure SetIntersectionOf(aChart: TGChart);
  end;

  TIntChart = class(specialize TGChart<Integer, Integer>)
  protected
    procedure WriteVertex(aStream: TStream; const aValue: Integer);
    procedure ReadVertex(aStream: TStream; out aValue: Integer);
  public
    procedure LoadDIMACSAscii(const aFileName: string);
    function  SeparateGraph(aVertex: Integer): TIntChart;
    function  SeparateGraphI(aIndex: SizeInt): TIntChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TIntChart;
    function  SubgraphFromTree(const aTree: TIntArray): TIntChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TIntChart;
    function  CreatePermutation(const aMap: TIntArray): TIntChart;
    function  Clone: TIntChart;
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

  { TGraphDotWriter }

  generic TGraphDotWriter<TVertex, TEdgeData, TEqRel> = class(
    specialize TGAbstractDotWriter<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TSimpleGraph = specialize TGSimpleGraph<TVertex, TEdgeData, TEqRel>;
    procedure WriteEdges(aGraph: TGraph; aList: TStrings) override;
  public
    constructor Create;
  end;

  TIntChartDotWriter = class(specialize TGraphDotWriter<Integer, TDummy, Integer>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string; override;
  end;

  { TStrChart
    warning: SaveToStream limitation for max string length = High(SmallInt) }
  TStrChart = class(specialize TGChart<string, string>)
  protected
    procedure WriteVertex(aStream: TStream; const aValue: string);
    procedure ReadVertex(aStream: TStream; out aValue: string);
  public
    function  SeparateGraph(const aVertex: string): TStrChart;
    function  SeparateGraphI(aIndex: SizeInt): TStrChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TStrChart;
    function  SubgraphFromTree(const aTree: TIntArray): TStrChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TStrChart;
    function  CreatePermutation(const aMap: TIntArray): TStrChart;
    function  Clone: TStrChart;
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
  { treats aVertexList as list of the pairs of source-target, last odd element ignored;
    returns count of added edges; }
    function AddEdges(const aVertexList: array of string): Integer;
  end;

  TStrChartDotWriter = class(specialize TGraphDotWriter<string, TDummy, string>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string; override;
  end;

  { TGWeightedGraph implements simple sparse undirected weighed graph based on adjacency lists;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean;

      TEdgeData must provide field/property/function Weight: TWeight;

      TWeight must be one of predefined signed numeric types;
      properties MinValue, MaxValue used as infinity weight values }
  generic TGWeightedGraph<TVertex, TWeight, TEdgeData, TEqRel> = class(
    specialize TGSimpleGraph<TVertex, TEdgeData, TEqRel>)
  private
  type
    TWeightHelper = specialize TGWeightHelper<TVertex, TWeight, TEdgeData, TEqRel>;

  public
  type
    TWeightArray  = TWeightHelper.TWeightArray;
    TWeightEdge   = TWeightHelper.TWeightEdge;
    TEdgeArray    = array of TWeightEdge;
    TEstimate     = TWeightHelper.TEstimate;
    TWeightMatrix = TWeightHelper.TWeightMatrix;
    TApspCell     = TWeightHelper.TApspCell;
    TApspMatrix   = TWeightHelper.TApspMatrix;

  protected
  type
    TWeightItem  = TWeightHelper.TWeightItem;
    TEdgeHelper  = specialize TGComparableArrayHelper<TWeightEdge>;

    function CreateEdgeArray: TEdgeArray;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function InfWeight: TWeight; static; inline;
    class function NegInfWeight: TWeight; static; inline;
    class function TotalWeight(const aEdges: TEdgeArray): TWeight; static;
    class function EdgeArray2IntEdgeArray(const a: TEdgeArray): TIntEdgeArray; static;
  { returns True if exists edge with negative weight }
    function ContainsNegWeightEdge: Boolean;
  { checks whether exists any negative weight cycle in connected component that
    contains a aRoot; if True then aCycle will contain indices of the vertices of the cycle;
    raises an exception if aRoot does not exist }
    function ContainsNegCycle(const aRoot: TVertex; out aCycle: TIntArray): Boolean; inline;
    function ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function SeparateGraph(const aVertex: TVertex): TGWeightedGraph;
    function SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
    function InducedSubgraph(const aVertexList: TIntArray): TGWeightedGraph;
    function SubgraphFromTree(const aTree: TIntArray): TGWeightedGraph;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TGWeightedGraph;
    function Clone: TGWeightedGraph;
{**********************************************************************************************************
  shortest path problem utilities
***********************************************************************************************************}

  { returns the weights of paths of minimal weight from a given vertex to the remaining
    vertices(SSSP), the weights of all edges MUST be nonnegative;
    the result contains in the corresponding component the weight of the path to the vertex or
    InfWeight if the vertex is unreachable; used Dijkstra's algorithm;
    raises an exception if aSrc does not exist }
    function MinPathsMap(const aSrc: TVertex): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths }
    function MinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { returns False if exists negative weight cycle reachable from aSrc,
    otherwise returns the weights of paths of minimal weight from a given vertex to the remaining
    vertices(SSSP); an aWeights will contain in the corresponding component the weight of the path
    to the vertex or InfWeight if the vertex is unreachable; used BFMT algorithm;
    raises an exception if aSrc does not exist  }
    function FindMinPathsMap(const aSrc: TVertex; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
  { same as above and in aPathTree returns paths }
    function FindMinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean;
  { returns the vertex path of minimal weight from a aSrc to aDst if it exists(pathfinding);
    the weights of all edges MUST be nonnegative;
    returns weight of the path or InfWeight if the vertex is unreachable in aWeight;
    used Dijkstra's algorithm; raises an exception if aSrc or aDst does not exist }
    function MinPath(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray; inline;
    function MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
    { returns the vertex path of minimal weight from a aSrc to aDst if it exists(pathfinding);
      the weights of all edges MUST be nonnegative;
      returns weight of the path or InfWeight if the vertex is unreachable in aWeight;
      used bidirectional Dijkstra's algorithm; raises an exception if aSrc or aDst does not exist }
    function MinPathBiDir(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
    function MinPathBiDirI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
  { returns False if exists negative weight cycle reachable from aSrc,
    otherwise returns the vertex path of minimal weight from a aSrc to aDst in aPath,
    if exists, and its weight in aWeight;
    to distinguish 'unreachable' and 'negative cycle': in case negative cycle aWeight returns ZeroWeight,
    but InfWeight if aDst unreachable; used BFMT algorithm;
    raises an exception if aSrc or aDst does not exist }
    function FindMinPath(const aSrc, aDst: TVertex; out aPath: TIntArray; out aWeight: TWeight): Boolean; inline;
    function FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the weights of all edges MUST be nonnegative; used A* algorithm if aEst <> nil;
    raises an exception if aSrc or aDst does not exist }
    function MinPathAStar(const aSrc, aDst: TVertex; out aWeight: TWeight; aEst: TEstimate): TIntArray; inline;
    function MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the weights of all edges MUST be nonnegative; used NBA* algorithm if aEst <> nil;
    raises an exception if aSrc or aDst does not exist }
    function MinPathNBAStar(const aSrc, aDst: TVertex; out aWeight: TWeight; aEst: TEstimate): TIntArray; inline;
    function MinPathNBAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
  { creates a matrix of weights of edges }
    function CreateWeightsMatrix: TWeightMatrix; inline;
  { returns True and the shortest paths between all pairs of vertices in matrix aPaths
    if non empty and no negative weight cycles exist,
    otherwise returns False and if negative weight cycle exists then in single cell of aPaths
    returns index of the vertex from which this cycle is reachable }
    function FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
  { raises an exception if aSrc or aDst does not exist }
    function ExtractMinPath(const aSrc, aDst: TVertex; const aPaths: TApspMatrix): TIntArray; inline;
    function ExtractMinPathI(aSrc, aDst: SizeInt; const aPaths: TApspMatrix): TIntArray;
  { returns False if is empty or exists  negative weight cycle reachable from aVertex,
    otherwise returns True and the weighted eccentricity of the aVertex in aValue }
    function FindEccentricity(const aVertex: TVertex; out aValue: TWeight): Boolean; inline;
    function FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
  { returns False if is not connected or exists negative weight cycle, otherwise
    returns True and weighted radius and diameter of the graph }
    function FindWeightedMetrics(out aRadius, aDiameter: TWeight): Boolean;
  { returns False if is not connected or exists negative weight cycle, otherwise
    returns True and indices of the central vertices in aCenter }
    function FindWeightedCenter(out aCenter: TIntArray): Boolean;
{**********************************************************************************************************
  minimum spanning tree utilities
***********************************************************************************************************}

  { finds a spanning tree(or spanning forest if not connected) of minimal weight; Kruskal's algorithm used }
    function MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntEdgeArray;
  { finds a spanning tree(or spanning forest if not connected) of minimal weight; Prim's algorithm used }
    function MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
  end;

  TRealWeight = specialize TGSimpleWeight<ValReal>;

  { TPointsChart }
  TPointsChart = class(specialize TGWeightedGraph<TPoint, ValReal, TRealWeight, TPoint>)
  protected
    procedure OnAddEdge(const aSrc, aDst: TPoint; var aData: TRealWeight);
    procedure WritePoint(aStream: TStream; const aValue: TPoint);
    procedure ReadPoint(aStream: TStream; out aValue: TPoint);
    procedure WriteData(aStream: TStream; const aValue: TRealWeight);
    procedure ReadData(aStream: TStream; out aValue: TRealWeight);
  public
    class function Distance(const aSrc, aDst: TPoint): ValReal; static;
    function  AddEdge(const aSrc, aDst: TPoint): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  EnsureConnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  RemoveCutPoints(const aRoot: TPoint; aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  EnsureBiconnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  SeparateGraph(aVertex: TPoint): TPointsChart;
    function  SeparateGraphI(aIndex: SizeInt): TPointsChart;
    function  InducedSubgraph(const aVertexList: TIntArray): TPointsChart;
    function  SubgraphFromTree(const aTree: TIntArray): TPointsChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TPointsChart;
    function  Clone: TPointsChart;
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
    function  MinPathAStar(const aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray; inline;
    function  MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray;
    function  MinPathNBAStar(const aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray; inline;
    function  MinPathNBAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray;
  end;

  { TGInt64Net specializes TWeight with Int64 }
  generic TGInt64Net<TVertex, TEdgeData, TEqRel>=class(specialize TGWeightedGraph<TVertex, Int64, TEdgeData, TEqRel>)
  public
  type
    TWeight = Int64;

  protected
  const
    MAX_WEIGHT = High(Int64);
    MIN_WEIGHT = Low(Int64);

    {$I GlobMinCutH.inc}

    function GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
    function GetTrivialMinCut(out aCut: TWeight): Boolean;
    function StoerWagner(out aCut: TIntSet): TWeight;
  public
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function SeparateGraph(const aVertex: TVertex): TGInt64Net;
    function SeparateGraphI(aIndex: SizeInt): TGInt64Net;
    function InducedSubgraph(const aVertexList: TIntArray): TGInt64Net;
    function SubgraphFromTree(const aTree: TIntArray): TGInt64Net;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TGInt64Net;
    function Clone: TGInt64Net;
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
  networks utilities treat the weight of the edge as its capacity
***********************************************************************************************************}
  type
    TGlobalNetState = (gnsOk, gnsTrivial, gnsDisconnected, gnsNegEdgeCapacity);

  { the capacities of all edges must be nonnegative; returns state of network;
    if state is gnsOk then returns the global minimum cut in aCut and it capacity in aCutWeight;
    otherwise empty cut and 0; used Stoer–Wagner algorithm }
    function MinWeightCutSW(out aCut: TCut; out aCutWeight: TWeight): TGlobalNetState;
  { the capacities of all edges must be nonnegative; returns state of network;
    if state is gnsOk then returns capacity of the global minimum cut in aCutWeight;
    otherwise 0; used Nagamochi-Ibaraki algorithm }
    function MinWeightCutNI(out aCutWeight: TWeight): TGlobalNetState;
  { the capacities of all edges must be nonnegative; returns state of network;
    if state is gnsOk then returns the global minimum cut in aCut and it capacity in aCutWeight;
    otherwise empty cut and 0; used Nagamochi-Ibaraki algorithm }
    function MinWeightCutNI(out aCut: TCut; out aCutWeight: TWeight): TGlobalNetState;
  { the capacities of all edges must be nonnegative; returns state of network;
    if state is gnsOk then returns the global minimum cut in aCut and array of the edges
    that cross the minimum cut in aCrossEdges; used Nagamochi-Ibaraki algorithm }
    function MinWeightCutNI(out aCut: TCut; out aCrossEdges: TEdgeArray): TGlobalNetState;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGSimpleGraph.TPlanarEmbedding.TAdjCwEnumerator }

function TGSimpleGraph.TPlanarEmbedding.TAdjCwEnumerator.GetCurrent: SizeInt;
begin
  Result := FList[CurrEdge].Target;
end;

function TGSimpleGraph.TPlanarEmbedding.TAdjCwEnumerator.MoveNext: Boolean;
begin
  if CurrEdge >= 0 then
    begin
      Result := FList[CurrEdge].Next <> FirstEdge;
      if Result then
        CurrEdge := FList[CurrEdge].Next;
    end
  else
    begin
      Result := FirstEdge <> NULL_INDEX;
      if Result then
        CurrEdge := FirstEdge;
    end;
end;

{ TGSimpleGraph.TPlanarEmbedding.TEdgeEnumerator }

function TGSimpleGraph.TPlanarEmbedding.TEdgeEnumerator.GetCurrent: TIntEdge;
begin
  with FList[CurrEdge] do
    Result := TIntEdge.Create(Source, Target);
end;

function TGSimpleGraph.TPlanarEmbedding.TEdgeEnumerator.MoveNext: Boolean;
begin
  Result := CurrEdge < System.Length(FList) - DEFAUL_INCREMENT;
  if Result then
    CurrEdge += DEFAUL_INCREMENT;
end;

{ TGSimpleGraph.TPlanarEmbedding.TAdjListCw }

function TGSimpleGraph.TPlanarEmbedding.TAdjListCw.GetEnumerator: TAdjCwEnumerator;
begin
  Result.FList := List;
  Result.FirstEdge := FirstEdge;
  Result.CurrEdge := NULL_INDEX;
end;

{ TGSimpleGraph.TPlanarEmbedding.TEdges }

function TGSimpleGraph.TPlanarEmbedding.TEdges.GetEnumerator: TEdgeEnumerator;
begin
  Result.FList := FList;
  Result.CurrEdge := -DEFAUL_INCREMENT;
end;

{ TGSimpleGraph.TPlanarEmbedding }

function TGSimpleGraph.TPlanarEmbedding.GetNodeCount: SizeInt;
begin
  Result := System.Length(FNodeList);
end;

function TGSimpleGraph.TPlanarEmbedding.GetEdgeCount: SizeInt;
begin
  Result := System.Length(FEdgeList) shr 1;
end;

function TGSimpleGraph.TPlanarEmbedding.GetCompCount: SizeInt;
begin
  Result := System.Length(FComponents);
end;

function TGSimpleGraph.TPlanarEmbedding.GetCompPop(aIndex: SizeInt): SizeInt;
begin
  if SizeUInt(aIndex) >= SizeUInt(ComponentCount) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [TYPE_NAME, aIndex]);
  Result := FComponents[aIndex].Count;
end;

function TGSimpleGraph.TPlanarEmbedding.GetComponent(aIndex: SizeInt): TIntArray;
begin
  if SizeUInt(aIndex) >= SizeUInt(ComponentCount) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [TYPE_NAME, aIndex]);
  Result := FComponents[aIndex].ToArray;
end;

procedure TGSimpleGraph.TPlanarEmbedding.Init(aNodeCount, aEdgeCount, aCompCount: SizeInt);
begin
  FNodeList := TIntArray.Construct(aNodeCount, NULL_INDEX);
  System.SetLength(FEdgeList, aEdgeCount shl 1);
  System.SetLength(FComponents, aCompCount);
  FCounter := 0;
end;

procedure TGSimpleGraph.TPlanarEmbedding.Init1;
begin
  FNodeList := [NULL_INDEX];
  System.SetLength(FComponents, 1);
  FComponents[0].Add(0);
end;

procedure TGSimpleGraph.TPlanarEmbedding.Init2(aConn: Boolean);
begin
  if aConn then
    begin
      FNodeList := [NULL_INDEX, NULL_INDEX];
      System.SetLength(FComponents, 1);
      FComponents[0].Add(0);
      FComponents[0].Add(1);
      System.SetLength(FEdgeList, DEFAUL_INCREMENT);
      AddEdge(0, 1);
      InsertFirst(1);
    end
  else
    begin
      FNodeList := [NULL_INDEX, NULL_INDEX];
      System.SetLength(FComponents, DEFAUL_INCREMENT);
      FComponents[0].Add(0);
      FComponents[1].Add(1);
    end;
end;

function TGSimpleGraph.TPlanarEmbedding.CreateEdge(aSrc, aDst: SizeInt): SizeInt;
begin
  if FCounter > System.Length(FEdgeList) - DEFAUL_INCREMENT then
    raise EGraphError.Create(SEInternalDataInconsist + ' in ' + TYPE_NAME);
  Result := FCounter;
  FCounter += DEFAUL_INCREMENT;
  with FEdgeList[Result] do
    begin
      Source := aSrc;
      Target := aDst;
    end;
  with FEdgeList[Succ(Result)] do
    begin
      Source := aDst;
      Target := aSrc;
    end;
end;

function TGSimpleGraph.TPlanarEmbedding.GetReverse(aEdge: SizeInt): SizeInt;
begin
  Result := Succ(aEdge) - (aEdge and 1) shl 1;
end;

function TGSimpleGraph.TPlanarEmbedding.AddEdge(aSrc, aDst: SizeInt): SizeInt;
var
  NewEdge, First, Last: SizeInt;
begin
  NewEdge := CreateEdge(aSrc, aDst);
  First := FNodeList[aSrc];
  if First <> NULL_INDEX then
    begin
      Last := FEdgeList[First].Prev;
      FEdgeList[NewEdge].Prev := Last;
      FEdgeList[NewEdge].Next := First;
      FEdgeList[Last].Next := NewEdge;
      FEdgeList[First].Prev := NewEdge;
    end
  else
    begin
      FEdgeList[NewEdge].Prev := NewEdge;
      FEdgeList[NewEdge].Next := NewEdge;
      FNodeList[aSrc] := NewEdge;
    end;
  Result := NewEdge;
end;

procedure TGSimpleGraph.TPlanarEmbedding.InsertFirst(aEdge: SizeInt);
var
  Src, First, Last: SizeInt;
begin
  Src := FEdgeList[aEdge].Source;
  First := FNodeList[Src];
  if First <> NULL_INDEX then
    begin
      Last := FEdgeList[First].Prev;
      FEdgeList[aEdge].Prev := Last;
      FEdgeList[aEdge].Next := First;
      FEdgeList[First].Prev := aEdge;
      FEdgeList[Last].Next := aEdge;
    end
  else
    begin
      FEdgeList[aEdge].Prev := aEdge;
      FEdgeList[aEdge].Next := aEdge;
    end;
  FNodeList[Src] := aEdge;
end;

procedure TGSimpleGraph.TPlanarEmbedding.InsertAfter(aEdge, aRef: SizeInt);
var
  Next: SizeInt;
begin
  Next := FEdgeList[aRef].Next;
  FEdgeList[aRef].Next := aEdge;
  FEdgeList[Next].Prev := aEdge;
  FEdgeList[aEdge].Prev := aRef;
  FEdgeList[aEdge].Next := Next;
end;

procedure TGSimpleGraph.TPlanarEmbedding.InsertBefore(aEdge, aRef: SizeInt);
var
  Prev: SizeInt;
begin
  Prev := FEdgeList[aRef].Prev;
  FEdgeList[aRef].Prev := aEdge;
  FEdgeList[Prev].Next := aEdge;
  FEdgeList[aEdge].Next := aRef;
  FEdgeList[aEdge].Prev := Prev;
end;

function TGSimpleGraph.TPlanarEmbedding.FindEdge(aSrc, aDst: SizeInt): SizeInt;
var
  First, Curr: SizeInt;
  c: SizeUInt;
begin
  Result := NULL_INDEX;
  c := SizeUInt(NodeCount);
  if (SizeUInt(aSrc) < c) and (SizeUInt(aDst) < c) then
    begin
      First := FNodeList[aSrc];
      Curr := First;
      while FEdgeList[Curr].Target <> aDst do
        begin
          Curr := FEdgeList[Curr].Next;
          if Curr = First then
            break;
        end;
      if FEdgeList[Curr].Target = aDst then
        Result := Curr;
    end;
end;

function TGSimpleGraph.TPlanarEmbedding.NextFaceEdge(aEdgeIdx: SizeInt): SizeInt;
begin
  Result := FEdgeList[GetReverse(aEdgeIdx)].Prev;
end;

function TGSimpleGraph.TPlanarEmbedding.IsEmpty: Boolean;
begin
  Result := FNodeList = nil;
end;

function TGSimpleGraph.TPlanarEmbedding.AdjListCw(aNode: SizeInt): TAdjListCw;
begin
  if SizeUInt(aNode) >= SizeUInt(NodeCount) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [TYPE_NAME, aNode]);
  Result.List := FEdgeList;
  Result.FirstEdge := FNodeList[aNode];
end;

function TGSimpleGraph.TPlanarEmbedding.Edges: TEdges;
begin
  Result.FList := FEdgeList;
end;

function TGSimpleGraph.TPlanarEmbedding.ContainsEdge(aSrc, aDst: SizeInt): Boolean;
begin
  Result := FindEdge(aSrc, aDst) <> NULL_INDEX;
end;

function TGSimpleGraph.TPlanarEmbedding.ContainsEdge(constref aEdge: TIntEdge): Boolean;
begin
  Result := ContainsEdge(aEdge.Source, aEdge.Destination);
end;

function TGSimpleGraph.TPlanarEmbedding.FindFirstEdge(aNode: SizeInt; out aEdge: TIntEdge): Boolean;
var
  First: SizeInt;
begin
  if SizeUInt(aNode) >= SizeUInt(NodeCount) then
    raise EGraphError.CreateFmt(SEClassIdxOutOfBoundsFmt, [TYPE_NAME, aNode]);
  First := FNodeList[aNode];
  Result := First <> NULL_INDEX;
  if Result then
    with FEdgeList[First] do
      aEdge := TIntEdge.Create(Source, Target)
  else
    aEdge := TIntEdge.Create(NULL_INDEX, NULL_INDEX);
end;

function TGSimpleGraph.TPlanarEmbedding.NextFaceEdge(constref aEdge: TIntEdge): TIntEdge;
var
  Curr: SizeInt;
begin
  Curr := FindEdge(aEdge.Source, aEdge.Destination);
  if Curr = NULL_INDEX then
    raise EGraphError.CreateFmt(SENoSuchEdgeFmt, [aEdge.Source, aEdge.Destination]);
  with FEdgeList[NextFaceEdge(Curr)] do
    Result := TIntEdge.Create(Source, Target);
end;

function TGSimpleGraph.TPlanarEmbedding.TraverseFace(constref aEdge: TIntEdge;
  aOnPassEdge: TOnPassEdge): TIntArray;
var
  Path: TIntVector;
  FirstArc, EnterArc, CurrArc, PrevArc: SizeInt;
begin
  Result := nil;
  FirstArc := FindEdge(aEdge.Source, aEdge.Destination);
  if FirstArc = NULL_INDEX then
    raise EGraphError.CreateFmt(SENoSuchEdgeFmt, [aEdge.Source, aEdge.Destination]);
  if aOnPassEdge <> nil then
    aOnPassEdge(aEdge.Source, aEdge.Destination);
  Path.Add(aEdge.Source);
  Path.Add(aEdge.Destination);
  EnterArc := GetReverse(FEdgeList[FirstArc].Next);
  PrevArc := FirstArc;
  CurrArc := NextFaceEdge(PrevArc);
  with FEdgeList[CurrArc] do
    begin
      if aOnPassEdge <> nil then
        aOnPassEdge(Source, Target);
      Path.Add(Target);
    end;
  while CurrArc <> EnterArc do
    begin
      PrevArc := CurrArc;
      CurrArc := NextFaceEdge(PrevArc);
      with FEdgeList[CurrArc] do
        begin
          if aOnPassEdge <> nil then
            aOnPassEdge(Source, Target);
          Path.Add(Target);
        end;
    end;
  Path.Add(aEdge.Source);
  Result := Path.ToArray;
end;

function TGSimpleGraph.TPlanarEmbedding.TraverseFace(constref aEdge: TIntEdge;
  aOnPassEdge: TNestPassEdge): TIntArray;
var
  Path: TIntVector;
  FirstArc, EnterArc, CurrArc, PrevArc: SizeInt;
begin
  Result := nil;
  FirstArc := FindEdge(aEdge.Source, aEdge.Destination);
  if FirstArc = NULL_INDEX then
    raise EGraphError.CreateFmt(SENoSuchEdgeFmt, [aEdge.Source, aEdge.Destination]);
  if aOnPassEdge <> nil then
    aOnPassEdge(aEdge.Source, aEdge.Destination);
  Path.Add(aEdge.Source);
  Path.Add(aEdge.Destination);
  EnterArc := GetReverse(FEdgeList[FirstArc].Next);
  PrevArc := FirstArc;
  CurrArc := NextFaceEdge(PrevArc);
  with FEdgeList[CurrArc] do
    begin
      if aOnPassEdge <> nil then
        aOnPassEdge(Source, Target);
      Path.Add(Target);
    end;
  while CurrArc <> EnterArc do
    begin
      PrevArc := CurrArc;
      CurrArc := NextFaceEdge(PrevArc);
      with FEdgeList[CurrArc] do
        begin
          if aOnPassEdge <> nil then
            aOnPassEdge(Source, Target);
          Path.Add(Target);
        end;
    end;
  Path.Add(aEdge.Source);
  Result := Path.ToArray;
end;

{$I SimpGraphHelp.inc}

{ TGSimpleGraph.TDistinctEdgeEnumerator }

function TGSimpleGraph.TDistinctEdgeEnumerator.GetCurrent: TEdge;
begin
  Result := TEdge.Create(FCurrIndex, FEnum.Current);
end;

function TGSimpleGraph.TDistinctEdgeEnumerator.MoveNext: Boolean;
begin
  repeat
    if FEnumDone then
      begin
        if FCurrIndex >= FLastIndex then
          exit(False);
        Inc(FCurrIndex);
        FEnum := FList[FCurrIndex].AdjList.GetEnumerator;
      end;
    Result := FEnum.MoveNext;
    FEnumDone := not Result;
    if Result then
      Result := FEnum.Current^.Destination > FCurrIndex;
  until Result;
end;

procedure TGSimpleGraph.TDistinctEdgeEnumerator.Reset;
begin
  FCurrIndex := -1;
  FEnumDone := True;
end;

{ TGSimpleGraph.TDistinctEdges }

function TGSimpleGraph.TDistinctEdges.GetEnumerator: TDistinctEdgeEnumerator;
begin
  Result.FList := Pointer(FGraph.FNodeList);
  Result.FLastIndex := Pred(FGraph.VertexCount);
  Result.FCurrIndex := -1;
  Result.FEnumDone := True;
end;

{ TGSimpleGraph }

procedure TGSimpleGraph.ResetTags;
var
  I: SizeInt;
begin
  for I := 0 to Pred(VertexCount) do
    FNodeList[I].Tag := I;
end;

function TGSimpleGraph.SeparateTag(aIndex: SizeInt): SizeInt;
begin
  if FNodeList[aIndex].Tag = aIndex then
    exit(aIndex);
  Result := SeparateTag(FNodeList[aIndex].Tag);
end;

function TGSimpleGraph.SeparateJoin(L, R: SizeInt): Boolean;
  function GetSeparateTag(aIndex: SizeInt): SizeInt;
  begin
    if FNodeList[aIndex].Tag = aIndex then
      exit(aIndex);
    Result := GetSeparateTag(FNodeList[aIndex].Tag);
    FNodeList[aIndex].Tag := Result;
  end;
begin
  L := GetSeparateTag(L);
  R := GetSeparateTag(R);
  if L = R then
    exit(False);
  if NextRandomBoolean then
    FNodeList[L].Tag := R
  else
    FNodeList[R].Tag := L;
  Result := True;
end;

procedure TGSimpleGraph.ValidateConnected;
var
  Queue: TIntQueue;
  Visited: TBoolVector;
  I, Curr, Next: SizeInt;
  p: PAdjItem;
begin
  if ConnectedValid then
    exit;
  if IsEmpty then
    begin
      FCompCount := 0;
      FConnectedValid := True;
      exit;
    end;
  Visited.Capacity := VertexCount;
  FCompCount := VertexCount;
  ResetTags;
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Curr := I;
        Visited.UncBits[Curr] := True;
        repeat
          for p in AdjLists[Curr]^ do
            begin
              Next := p^.Key;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  Queue.Enqueue(Next);
                  if SeparateJoin(Curr, Next) then
                    Dec(FCompCount);
                end;
            end;
        until not Queue{%H-}.TryDequeue(Curr);
      end;
  FConnected := FCompCount = 1;
  FConnectedValid := True;
end;

function TGSimpleGraph.GetConnected: Boolean;
begin
  Result := SeparateCount = 1;
end;

function TGSimpleGraph.GetDensity: Double;
begin
  if NonEmpty then
    Result := (Double(EdgeCount) * 2)/(Double(VertexCount) * Double(Pred(VertexCount)))
  else
    Result := 0.0;
end;

function TGSimpleGraph.CreateSkeleton: TSkeleton;
var
  I: SizeInt;
begin
  Result := TSkeleton.Create(VertexCount);
  Result.FEdgeCount := EdgeCount;
  for I := 0 to Pred(VertexCount) do
    Result[I]^.AssignList(AdjLists[I]);
end;

procedure TGSimpleGraph.AssignGraph(aGraph: TGSimpleGraph);
var
  I: SizeInt;
begin
  Clear;
  FCount := aGraph.VertexCount;
  FEdgeCount := aGraph.EdgeCount;
  FCompCount := aGraph.FCompCount;
  FTitle := aGraph.Title;
  FDescription := aGraph.FDescription;
  FConnected := aGraph.Connected;
  FConnectedValid := aGraph.ConnectedValid;
  if aGraph.NonEmpty then
    begin
      FChainList := System.Copy(aGraph.FChainList);
      System.SetLength(FNodeList, System.Length(aGraph.FNodeList));
      for I := 0 to Pred(VertexCount) do
        FNodeList[I].Assign(aGraph.FNodeList[I]);
    end;
end;

procedure TGSimpleGraph.AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
var
  v: TIntArray = nil;
  I, J, Tag: SizeInt;
begin
  v.Length := aGraph.SeparatePopI(aIndex);
  Tag := aGraph.SeparateTag(aIndex);
  J := 0;
  for I := 0 to Pred(aGraph.VertexCount) do
    if aGraph.SeparateTag(I) = Tag then
      begin
        v[J] := I;
        Inc(J);
      end;
  AssignVertexList(aGraph, v);
end;

procedure TGSimpleGraph.AssignPermutation(aGraph: TGSimpleGraph; const aMap: TIntArray);
var
  I, IMap, KeyMap: SizeInt;
  p: PAdjItem;
begin
  if not aGraph.IsNodePermutation(aMap) then
    raise EGraphError.Create(SEInputIsNotProperPermut);
  Clear;
  EnsureCapacity(aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    DoAddVertex(aGraph.FNodeList[I].Vertex, IMap);
  for I := 0 to Pred(VertexCount) do
    AdjLists[aMap[I]]^.EnsureCapacity(aGraph.AdjLists[I]^.Count);
  for I := 0 to Pred(VertexCount) do
    begin
      IMap := aMap[I];
      for p in aGraph.AdjLists[I]^ do
        if p^.Key > I then
          begin
            KeyMap := aMap[p^.Key];
            ////DoAddEdge(IMap, KeyMap, p^.Data);
            FNodeList[IMap].AdjList.Append(TAdjItem.Create(KeyMap, p^.Data));
            FNodeList[KeyMap].AdjList.Append(TAdjItem.Create(IMap, p^.Data));
            Inc(FEdgeCount);
            if SeparateJoin(IMap, KeyMap) then
              begin
                Dec(FCompCount);
                FConnected := FCompCount = 1;
              end;
          end;
    end;
end;

function TGSimpleGraph.GetSeparateCount: SizeInt;
begin
  if not ConnectedValid then
    ValidateConnected;
  Result := FCompCount;
end;

function TGSimpleGraph.CountPop(aTag: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    Result += Ord(SeparateTag(I) = aTag);
end;

function TGSimpleGraph.MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  I: SizeInt;
  d: TEdgeData;
begin
  Result := 0;
  d := Default(TEdgeData);
  for I := 1 to Pred(VertexCount) do
    if SeparateTag(0) <> SeparateTag(I) then
      begin
        if Assigned(aOnAddEdge) then
          aOnAddEdge(FNodeList[0].Vertex, FNodeList[I].Vertex, d);
        AddEdgeI(0, I, d);
        Inc(Result);
      end;
end;

function TGSimpleGraph.CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  Visited: TBoolVector;
  Next: SizeInt;
begin
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  Visited.Capacity := VertexCount;
  Visited.UncBits[aRoot] := True;
  {%H-}Stack.Push(aRoot);
  while Stack.TryPeek(aRoot) do
    if AdjEnums[aRoot].MoveNext then
      begin
        Next := AdjEnums[aRoot].Current;
        if not Visited.UncBits[Next] then
          begin
            Visited.UncBits[Next] := True;
            Parents[Next] := aRoot;
            Stack.Push(Next);
          end
        else
          if Parents[aRoot] <> Next then
            begin
              aCycle := TreeExtractCycle(Parents, Next, aRoot);
              exit(True);
            end;
      end
    else
      Stack.Pop;
  Result := False;
end;

function TGSimpleGraph.CheckAcyclic: Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  Visited: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  Visited.Capacity := VertexCount;
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Visited.UncBits[I] := True;
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if Parents[Curr] <> Next then
                  exit(False);
            end
          else
            Stack.Pop;
      end;
  Result := True;
end;

function TGSimpleGraph.FindPerfectElimOrd(aOnNodeDone: TSpecNodeDone; out aPeoSeq: TIntArray): Boolean;
var
  Queue: TINodePqMax;
  InQueue: TBoolVector;
  Index2Ord: TIntArray = nil;
  Lefts: TIntSet;
  I, J, MaxOrd, Nearest: SizeInt;
  Node: TIntNode;
  AdjLst: PAdjList;
  p: PAdjItem;
begin
  aPeoSeq := nil;
  //max cardinality search
  Queue := TINodePqMax.Create(VertexCount);
  InQueue.InitRange(VertexCount);
  for I := 0 to Pred(VertexCount)do
    Queue.Enqueue(I, TIntNode.Create(I, 0));
  aPeoSeq.Length := VertexCount;
  Index2Ord.Length := VertexCount;
  I := 0;
  while Queue.TryDequeue(Node) do
    begin
      InQueue.UncBits[{%H-}Node.Index] := False;
      aPeoSeq[I] := Node.Index;
      Index2Ord[Node.Index] := I;
      Inc(I);
      MaxOrd := NULL_INDEX;
      Nearest := NULL_INDEX;
      {%H-}Lefts.MakeEmpty;
      for p in AdjLists[Node.Index]^ do
        if InQueue.UncBits[p^.Key] then
          Queue.Update(p^.Key, TIntNode.Create(p^.Key, Succ(Queue.GetItemPtr(p^.Key)^.Data)))
        else
          begin
            J := Index2Ord[p^.Key];
            if J > MaxOrd then
              begin
                MaxOrd := J;
                Nearest := p^.Key;
              end;
            Lefts.Push(p^.Key);
          end;
      if Nearest <> NULL_INDEX then
        begin
          AdjLst := AdjLists[Nearest];
          for J in Lefts do
            if (J <> Nearest) and not AdjLst^.Contains(J) then
              begin
                aPeoSeq := nil;
                exit(False);
              end;
        end;
      if aOnNodeDone <> nil then
        aOnNodeDone(Node.Index, Lefts);
    end;
  Result := True;
end;

function TGSimpleGraph.FindChordalMaxClique(out aClique: TIntSet): Boolean;
  procedure NodeDone(aIndex: SizeInt; const aLefts: TIntSet);
  begin
    if aLefts.Count > Pred(aClique.Count) then
      begin
        aClique.Assign(aLefts);
        aClique.Push(aIndex);
      end;
  end;
var
  Dummy: TIntArray;
begin
  aClique.Clear;
  Result := FindPerfectElimOrd(@NodeDone, Dummy);
  if not Result then
    aClique.Clear;
end;

function TGSimpleGraph.FindChordalMis(out aMis: TIntSet): Boolean;
var
  Peo: TIntArray;
  Visited: TBoolVector;
  I, Curr: SizeInt;
  p: PAdjItem;
begin
  aMis.Clear;
  Result := FindPerfectElimOrd(nil, Peo);
  if Result then
    begin
      Visited.Capacity := VertexCount;
      for I := Pred(VertexCount) downto 0 do
        begin
          Curr := Peo[I];
          if Visited.UncBits[Curr] then
            continue;
          aMis.Push(Curr);
          for p in AdjLists[Curr]^ do
            Visited.UncBits[p^.Key] := True;
        end;
    end;
end;

function TGSimpleGraph.FindChordalColoring(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
  procedure NodeDone(aIndex: SizeInt; const aLefts: TIntSet);
  begin
    aIndex := Succ(aLefts.Count);
    if aIndex > aMaxColor then
      aMaxColor := aIndex;
  end;
var
  PeoSeq: TIntArray;
  OnLeft: TBoolVector;
  AvailColors: TBoolVector;
  I, Curr: SizeInt;
  p: PAdjItem;
begin
  aMaxColor := 0;
  aColors := nil;
  Result := FindPerfectElimOrd(@NodeDone, PeoSeq);
  if Result then
    begin
      aColors.Length := VertexCount;
      OnLeft.Capacity := VertexCount;
      for I := 0 to Pred(VertexCount) do
        begin
          Curr := PeoSeq[I];
          AvailColors.InitRange(Succ(aMaxColor));
          AvailColors.UncBits[0] := False;
          for p in AdjLists[Curr]^ do
            if OnLeft.UncBits[p^.Key] then
              AvailColors.UncBits[aColors[p^.Key]] := False;
          aColors[Curr] := AvailColors.Bsf;
          OnLeft.UncBits[Curr] := True;
        end;
    end
  else
    aMaxColor := 0;
end;

function TGSimpleGraph.GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TCliqueHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxCliqueConnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Clique: TIntSet;
  I: SizeInt;
begin
  if IsComplete then
    exit(TIntHelper.CreateRange(0, Pred(VertexCount)));
  if IsBipartite then
    begin
      if not AdjLists[0]^.FindFirst(I) then
        raise EGraphError.Create(SEInternalDataInconsist);
      exit([0, I]);
    end;
  if FindChordalMaxClique(Clique) then
    exit(Clique.ToArray);
  if (VertexCount >= COMMON_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    Result := GetMaxClique(aTimeOut, aExact)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMaxCliqueBP(aTimeOut, aExact)
    else
      Result := GetMaxCliqueBP256(aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxCliqueDisconnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  CurrClique: TIntArray;
  I, J, Curr: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
  Exact: Boolean;
begin
  aExact := False;
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Result := GreedyMaxClique;
  if SecondsBetween(Now, StartTime) < TimeOut then
    begin
      Separates := FindSeparates;
      for I := 0 to System.High(Separates) do
        if Separates[I].Count > Result.Length then
          begin
            g := InducedSubgraph(Separates[I].ToArray);
            try
              CurrClique := g.FindMaxClique(Exact, TimeOut - SecondsBetween(Now, StartTime));
              if CurrClique.Length > Result.Length then
                begin
                  Curr := 0;
                  Result.Length := CurrClique.Length;
                  for J in CurrClique do
                    begin
                      Result[Curr] := IndexOf(g[J]);
                      Inc(Curr);
                    end;
                end;
            finally
              g.Free;
            end;
            if not Exact then
              exit;
          end;
      aExact := True;
    end;
end;

function TGSimpleGraph.GreedyMatching: TIntEdgeArray;
var
  Nodes: TIntArray;
  Matched: TBoolVector;
  CurrPos, Size, Curr, Next: SizeInt;
  p: PAdjItem;
begin
  Nodes := SortNodesByDegree(soAsc);
  Matched.Capacity := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  CurrPos := 0;
  Size := 0;
  while CurrPos < VertexCount do
    begin
      if not Matched.UncBits[Nodes[CurrPos]] then
        begin
          Curr := Nodes[CurrPos];
          Next := NULL_INDEX;
          for p in AdjLists[Curr]^ do // find adjacent non matched node
            if not Matched.UncBits[p^.Destination] then
              begin
                Next := p^.Destination;
                break;
              end;
          if Next <> NULL_INDEX then // node found
            begin
              Matched.UncBits[Curr] := True;
              Matched.UncBits[Next] := True;
              if System.Length(Result) = Size then
                System.SetLength(Result, Size shl 1);
              Result[Size] := TIntEdge.Create(Curr, Next);
              Inc(Size);
            end;
        end;
      Inc(CurrPos);
    end;
  System.SetLength(Result, Size);
end;

function TGSimpleGraph.GreedyMatching2: TIntEdgeArray;
var
  Nodes: TINodePqMin;
  Matched: TBoolVector;
  Node: TIntNode;
  Size, I, Deg, s, d: SizeInt;
  p: PAdjItem;
begin
  Nodes := TINodePqMin.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    {%H-}Nodes.Enqueue(I, TIntNode.Create(I, DegreeI(I)));
  Matched.Capacity := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  Size := 0;
  while Nodes.TryDequeue(Node) do
    if not Matched.UncBits[{%H-}Node.Index] then
      begin
        s := Node.Index;
        d := NULL_INDEX;
        Deg := VertexCount;
        for p in AdjLists[s]^ do // find adjacent node with min degree
          begin
            I := p^.Destination;
            if not Matched.UncBits[I] then
              begin
                Node := Nodes.GetItem(I);
                if  Node.Data < Deg then
                  begin
                    Deg := Node.Data;
                    d := I;
                  end;
                Dec(Node.Data);
                Nodes.Update(I, Node);
              end;
          end;
        if d <> NULL_INDEX then // node found
          begin
            for p in AdjLists[d]^ do
              begin
                I := p^.Destination;
                if (I <> s) and not Matched.UncBits[I] then
                  begin
                    Node := Nodes.GetItem(I);
                    Dec(Node.Data);
                    Nodes.Update(I, Node);
                  end;
              end;
            Matched.UncBits[s] := True;
            Matched.UncBits[d] := True;
            Nodes.Remove(d);
            if System.Length(Result) = Size then
              System.SetLength(Result, Size shl 1);
            Result[Size] := TIntEdge.Create(s, d);
            Inc(Size);
          end;
      end;
  System.SetLength(Result, Size);
end;

procedure TGSimpleGraph.ListCliquesBP(aOnFind: TOnSetFound);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliquesBP256(aOnFind: TOnSetFound);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliques(aOnFind: TOnSetFound);
var
  Helper: TCliqueHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

function TGSimpleGraph.GetMisBipartite(const w, g: TIntArray): TIntArray;
var
  Helper: THKMatch;
  Lefts, LeftsVisit, LeftsFree, RightsUnvisit, Visited: TBoolVector;
  Match: TIntArray;
  e: TIntEdge;
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  I, Curr, Next: SizeInt;
  CurrInLefts: Boolean;
begin
  Lefts.Capacity := VertexCount;
  LeftsVisit.Capacity := VertexCount;
  LeftsFree.Capacity := VertexCount;
  RightsUnvisit.Capacity := VertexCount;
  if System.Length(w) < System.Length(g) then
    begin
      for I in w do
        begin
          Lefts.UncBits[I] := True;
          LeftsFree.UncBits[I] := True;
        end;
      for I in g do
        RightsUnvisit.UncBits[I] := True;
    end
  else
    if System.Length(w) > System.Length(g) then
      begin
        for I in g do
          begin
            Lefts.UncBits[I] := True;
            LeftsFree.UncBits[I] := True;
          end;
        for I in w do
          RightsUnvisit.UncBits[I] := True;
      end
    else
      exit(w); ////

  Match := CreateIntArray;
  for e in Helper.MaxMatching(Self, w, g) do
    begin
      LeftsFree.UncBits[e.Source] := False;
      LeftsFree.UncBits[e.Destination] := False;
      Match[e.Source] := e.Destination;
      Match[e.Destination] := e.Source;
    end;

  //find nodes that not belong min vertex cover
  Visited.Capacity := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  for I in LeftsFree do
    begin
      {%H-}Stack.Push(I);
      Visited.UncBits[I] := True;
      while Stack.TryPeek(Curr) do
        begin
          CurrInLefts := Lefts.UncBits[Curr];
          if AdjEnums[Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  if CurrInLefts xor (Match[Curr] = Next) then
                    Stack.Push(Next);
                end;
            end
          else
            begin
              Stack.Pop;
              if CurrInLefts then
                LeftsVisit.UncBits[Curr] := True
              else
                RightsUnvisit.UncBits[Curr] := False;
            end;
        end;
    end;

  Match := nil;
  Lefts.Capacity := 0;
  LeftsFree.Capacity := 0;

  Result.Length := LeftsVisit.PopCount + RightsUnvisit.PopCount;
  I := 0;
  for Curr in LeftsVisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
  for Curr in RightsUnvisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
end;

function TGSimpleGraph.GetMisBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMisBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMisConnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  w, g: TIntArray;
  Mis: TIntSet;
begin
  if IsComplete then
    exit([0]);
  if IsBipartite(w, g) then
    exit(GetMisBipartite(w, g));
  if FindChordalMis(Mis) then
    exit(Mis.ToArray);
  if VertexCount > TBits256.BITNESS then
    Result := GetMisBP(aTimeOut, aExact)
  else
    Result := GetMisBP256(aTimeOut, aExact);
end;

function TGSimpleGraph.GetMisDisconnected(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  CurrMis, Mis: TIntArray;
  I, J, Curr: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
  Exact: Boolean;
begin
  aExact := False;
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Result := GreedyMis;
  Mis := nil;
  if SecondsBetween(Now, StartTime) < TimeOut then
    begin
      Separates := FindSeparates;
      for I := 0 to System.High(Separates) do
        begin
          g := InducedSubgraph(Separates[I].ToArray);
          try
            CurrMis := g.FindMis(Exact, TimeOut - SecondsBetween(Now, StartTime));
            Curr := Mis.Length;
            Mis.Length := Curr + CurrMis.Length;
            for J in CurrMis do
              begin
                Mis[Curr] := IndexOf(g[J]);
                Inc(Curr);
              end;
          finally
            g.Free;
          end;
          if not Exact then
            exit;
        end;
      if Mis.Length > Result.Length then
        Result := Mis;
      aExact := True;
    end;
end;

procedure TGSimpleGraph.ListIsBP(aOnFind: TOnSetFound);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListMIS(Self, aOnFind);
end;

procedure TGSimpleGraph.ListIsBP256(aOnFind: TOnSetFound);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListMIS(Self, aOnFind);
end;

function TGSimpleGraph.GetGreedyMis: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := NULL_INDEX;
      MinPop := Succ(VertexCount);
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMisBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := NULL_INDEX;
      MinPop := Succ(VertexCount);
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand.UncBits[J] := False;
      Cand.Subtract(Matrix[J]);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMinIs: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := NULL_INDEX;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMinIsBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := NULL_INDEX;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(Matrix[J]);
      Cand.UncBits[J] := False;
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

procedure TGSimpleGraph.DoListDomSets(aMaxSize: SizeInt; aOnFind: TOnSetFound);
var
  Columns, Blocks: TBoolMatrix;
  CurrSet: TBoolVector;
  NodeCount, CurrCount: SizeInt;
  Cancelled: Boolean;
  procedure InitMsc;
  var
    Excluded: TBoolVector;
    I, J: SizeInt;
  begin
    NodeCount := VertexCount;
    CurrSet.Capacity := NodeCount;
    Columns := CreateBoolMatrix;
    for I := 0 to Pred(NodeCount) do
      begin
        Columns[I].UncBits[I] := True;
        if Columns[I].PopCount = 1 then
          CurrSet.UncBits[I] := True;
      end;
    Excluded.Capacity := NodeCount;
    for I := 0 to Pred(NodeCount) do
      if not CurrSet.UncBits[I] then
        for J := 0 to Pred(NodeCount) do
          if (J <> I) and Columns[J].Contains(Columns[I]) then
            begin
              Excluded.UncBits[I] := True;
              break;
            end;
    System.SetLength(Blocks, NodeCount);
    for I := 0 to Pred(NodeCount) do
      if not CurrSet.UncBits[I] then
        begin
          Blocks[I].Capacity := NodeCount;
          for J := 0 to Pred(NodeCount) do
            if not Excluded.UncBits[J] and Columns[J].UncBits[I] then
              Blocks[I].UncBits[J] := True;
        end;
    CurrCount := CurrSet.PopCount;
  end;
  procedure Extend(const aCand, aTested: TBoolVector);
  var
    NewTested: TBoolVector;
    I, Next: SizeInt;
  begin
    if aCand.NonEmpty then
      begin
        if CurrCount >= aMaxSize then
          exit;
        Next := aCand.Bsf;
        NewTested := aTested;
        for I in Blocks[Next] do
          if not aTested.UncBits[I] then
            begin
              CurrSet.UncBits[I] := True;
              NewTested.UncBits[I] := True;
              Inc(CurrCount);
              Extend(aCand.Difference(Columns[I]), NewTested);
              if Cancelled then
                exit;
              CurrSet.UncBits[I] := False;
              Dec(CurrCount);
            end;
      end
    else
      aOnFind(CurrSet.ToArray, Cancelled);
  end;
var
  Cand, Tested: TBoolVector;
begin
  Cancelled := False;
  InitMsc;
  Cand.InitRange(VertexCount);
  Cand.Subtract(CurrSet{%H-});
  Tested.Capacity := VertexCount;
  Extend(Cand, Tested);
end;

function TGSimpleGraph.GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper256;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.ColorTrivial(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
var
  Cycle: TIntArray;
  Cols: TColorArray;
  I, Hub: SizeInt;
begin
  aMaxColor := 1;
  aColors := nil;
  if IsEmpty then
    exit(True);
  if IsComplete then
    begin
      aColors.Length := VertexCount;
      for I := 0 to Pred(VertexCount) do
        aColors[I] := Succ(I);
      aMaxColor := VertexCount;
      exit(True);
    end;
  if IsBipartite(Cols) then
    begin
      aColors.Length := VertexCount;
      for I := 0 to System.High(aColors) do
        aColors[I] := Cols[I];
      aMaxColor := 2;
      exit(True);
    end;
  if Odd(VertexCount) and IsCycle then
    begin
      if not CycleExists(0, Cycle) then
        exit(False); //todo: internal error ???
      aColors.Length := VertexCount;
      for I := 0 to VertexCount - 2 do
        aColors[Cycle[I]] := Succ(Ord(Odd(I)));
      aColors[Cycle[Pred(VertexCount)]] := 3;
      aMaxColor := 3;
      exit(True);
    end;
  if IsWheel(Hub) then
    begin
      aMaxColor := GreedyColorRlf(aColors);
      exit(True);
    end;
  if FindChordalColoring(aMaxColor, aColors) then
    exit(True);
  Result := False;
end;

function TGSimpleGraph.ColorConnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
var
  Helper: TExactColor;
begin
  Result := Helper.Colorize(Self, aTimeOut, aColors, aExact);
end;

function TGSimpleGraph.ColorDisconnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  ColMap: TIntArray;
  I, J, ColCount, MaxColCount: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
  Exact: Boolean;
begin
  aExact := False;
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Result := GreedyColorRlf(aColors);
  if SecondsBetween(Now, StartTime) < TimeOut then
    begin
      Separates := FindSeparates;
      MaxColCount := 0;
      for I := 0 to System.High(Separates) do
        begin
          g := InducedSubgraph(Separates[I].ToArray);
          try
            ColCount := g.VertexColoring(ColMap, Exact, TimeOut - SecondsBetween(Now, StartTime));
            for J := 0 to System.High(ColMap) do
              aColors[IndexOf(g[J])] := ColMap[J];
            if ColCount > MaxColCount then
              MaxColCount := ColCount;
          finally
            g.Free;
          end;
          if not Exact then
            exit;
        end;
      if MaxColCount < Result then
        Result := MaxColCount;
      aExact := True;
    end;
end;

function TGSimpleGraph.ColorableConnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
var
  Helper: TExactColor;
begin
  Result := Helper.IsColorable(Self, aK, aTimeOut, aColors);
end;

function TGSimpleGraph.ColorableDisconnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  ColMap: TIntArray;
  I, J: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
begin
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Separates := FindSeparates;
  aColors.Length := VertexCount;
  for I := 0 to System.High(Separates) do
    begin
      g := InducedSubgraph(Separates[I].ToArray);
      try
        Result := g.IsKColorable(aK, ColMap, TimeOut - SecondsBetween(Now, StartTime));
        if Result = tlTrue then
          for J := 0 to System.High(ColMap) do
            aColors[IndexOf(g[J])] := ColMap[J];
      finally
        g.Free;
      end;
      if (Result = tlFalse) or (Result = tlUnknown) then
        begin
          aColors := nil;
          exit;
        end;
    end;
end;

function TGSimpleGraph.GreedyColorRlf(out aColors: TIntArray): SizeInt;
var
  Helper: TGreedyColorRlf;
begin
  Result := Helper.Execute(Self, aColors);
end;

function TGSimpleGraph.GreedyColor(out aColors: TIntArray): SizeInt;
var
  Queue: TINodePqMax;
  Nodes: array of TIntNode;
  Achromatic, CurrIS: TBoolVector;
  Node: TIntNode;
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(Nodes, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Nodes[I] := TIntNode.Create(I, AdjLists[I]^.Count);
  Queue := TINodePqMax.Create(VertexCount);
  aColors.Length := VertexCount;
  Achromatic.InitRange(VertexCount);
  Result := 0;
  while Achromatic.NonEmpty do
    begin
      Inc(Result);
      CurrIS := Achromatic;
      for I in Achromatic do
        {%H-}Queue.Enqueue(I, Nodes[I]);
      while Queue.TryDequeue(Node) do
        if CurrIS.UncBits[Node.Index] then
          begin
            CurrIS.UncBits[Node.Index] := False;
            Achromatic.UncBits[Node.Index] := False;
            aColors[Node.Index] := Result;
            for p in AdjLists[Node.Index]^ do
              if Achromatic.UncBits[p^.Key] then
                begin
                  Dec(Nodes[p^.Key].Data);
                  CurrIS.UncBits[p^.Key] := False;
                end;
          end;
    end;
end;

procedure TGSimpleGraph.SearchForCutVertices(aRoot: SizeInt; var aPoints: TIntHashSet);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = NULL_INDEX then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              ChildCount += Ord(Curr = aRoot);
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        if Curr <> aRoot then
          begin
            Next := Curr;
            Curr := Parents[Curr];
            if LowPt[Curr] > LowPt[Next] then
              LowPt[Curr] := LowPt[Next];
            if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
              aPoints.Add(Curr);
          end;
      end;
  if ChildCount > 1 then
    aPoints.Add(aRoot);
end;

function TGSimpleGraph.CutVertexExists(aRoot: SizeInt): Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = NULL_INDEX then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        if Curr <> aRoot then
          begin
            Next := Curr;
            Curr := Parents[Curr];
            if LowPt[Curr] > LowPt[Next] then
              LowPt[Curr] := LowPt[Next];
            if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
              exit(True);
          end;
      end;
  Result := ChildCount > 1;
end;

procedure TGSimpleGraph.SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents, Across: TIntArray;
  Counter, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Across := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = NULL_INDEX then
            begin
              if Across[Curr] = NULL_INDEX then
                Across[Curr] := Next;
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        if Curr <> aRoot then
          begin
            Next := Curr;
            Curr := Parents[Curr];
            if LowPt[Curr] > LowPt[Next] then
              LowPt[Curr] := LowPt[Next];
            if LowPt[Next] >= PreOrd[Curr] then
              begin
                if Next = Across[Curr] then
                  begin
                    if Curr <> aRoot then
                      aEdges.Add(TIntEdge.Create(Parents[Curr], Next));
                  end
                else
                  aEdges.Add(TIntEdge.Create(Across[Curr], Next));
              end;
          end;
      end;
end;

procedure TGSimpleGraph.SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
var
  Stack: TSimpleStack;
  EdgeStack: TIntEdgeVector;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = NULL_INDEX then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Stack.Push(Next);
              EdgeStack.Add(TIntEdge.Create(Curr, Next));
            end
          else
            if PreOrd[Curr] > PreOrd[Next] then
              begin
                if LowPt[Curr] > PreOrd[Next] then
                  LowPt[Curr] := PreOrd[Next];
                EdgeStack.Add(TIntEdge.Create(Curr, Next));
              end;
      end
    else
      begin
        Stack.Pop;
        if Curr <> aRoot then
          begin
            Next := Curr;
            Curr := Parents[Curr];
            if LowPt[Curr] > LowPt[Next] then
              LowPt[Curr] := LowPt[Next];
            if LowPt[Next] >= PreOrd[Curr] then
              begin
                I := EdgeStack.Count;
                with EdgeStack do
                  repeat Dec(I);
                  until (UncMutable[I]^.Source = Curr) and (UncMutable[I]^.Destination = Next);
                aComp.Add(EdgeStack.ExtractAll(I, EdgeStack.Count));
              end;
          end;
      end;
end;

function TGSimpleGraph.BridgeExists: Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              if Parents[Curr] <> NULL_INDEX then
                begin
                  Next := Curr;
                  Curr := Parents[Curr];
                  if LowPt[Curr] > LowPt[Next] then
                    LowPt[Curr] := LowPt[Next];
                  if LowPt[Next] > PreOrd[Curr] then
                    exit(True);
                end;
            end;
      end;
  Result := False;
end;

procedure TGSimpleGraph.SearchForBridges(var aBridges: TIntEdgeVector);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              if Parents[Curr] <> NULL_INDEX then
                begin
                  Next := Curr;
                  Curr := Parents[Curr];
                  if LowPt[Curr] > LowPt[Next] then
                    LowPt[Curr] := LowPt[Next];
                  if LowPt[Next] > PreOrd[Curr] then
                    aBridges.Add(TIntEdge.Create(Curr, Next));
                end;
            end;
      end;
end;

procedure TGSimpleGraph.SearchForCycleBasis(out aCycles: TIntArrayVector);
var
  Stack: TSimpleStack;
  Visited: TBoolVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Curr, Next: SizeInt;
begin
  Visited.Capacity := VertexCount;
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
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
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aCycles.Add(TreeExtractCycle(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

procedure TGSimpleGraph.SearchForCycleBasisVector(out aVector: TIntVector);
var
  Stack: TSimpleStack;
  Visited: TBoolVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Next: SizeInt;
  Curr: SizeInt = -1;
begin
  Visited.Capacity := VertexCount;
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if not Visited.UncBits[I] then
      begin
        Visited.UncBits[I] := True;
        Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited.UncBits[Next] then
                begin
                  Visited.UncBits[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aVector.Add(TreeCycleLen(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

function TGSimpleGraph.GetCycleBasisVector: TIntArray;
var
  v: TIntVector;
begin
  Result := nil;
  if IsTree then
    exit;
  SearchForCycleBasisVector(v);
  if v.Count <> CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  Result := v.ToArray;
  TIntHelper.Sort(Result);
end;

function TGSimpleGraph.CreateDegreeVector: TIntArray;
var
  v: TIntArray = nil;
  I: SizeInt;
begin
  v.Length := VertexCount;
  for I := 0 to Pred(VertexCount) do
    v[I] := AdjLists[I]^.Count;
  TIntHelper.Sort(v);
  Result := v;
end;

function TGSimpleGraph.CreateNeighDegreeVector: TIntArray;
var
  v: TIntArray = nil;
  I: SizeInt;
  DegSum: Int64;
  p: PAdjItem;
begin
  System.SetLength(v, VertexCount);
  for I := 0 to Pred(VertexCount) do
    begin
      DegSum := 0;
      for p in AdjLists[I]^ do
      {$PUSH}{$Q+}
        DegSum += AdjLists[p^.Key]^.Count;
      {$POP}
      v[I] := DegSum;
    end;
  TIntHelper.Sort(v);
  Result := v;
end;

function TGSimpleGraph.CreateComplementDegreeArray: TIntArray;
var
  I: SizeInt;
begin
  Result{%H-}.Length := VertexCount;
  for I := 0 to Pred(VertexCount) do
    Result[I] := VertexCount - AdjLists[I]^.Count;
end;

function TGSimpleGraph.SortNodesByWidth(o: TSortOrder): TIntArray;
var
  Queue: specialize TGPairHeapMin<TSbWNode>;
  List: TIntArray = nil;
  InQueue: TBoolVector;
  Item: TSbWNode = (Index: -1; WDegree: -1; Degree: -1;);
  I: SizeInt;
  p: PAdjItem;
begin
  Queue := specialize TGPairHeapMin<TSbWNode>.Create(VertexCount);
  List.Length := VertexCount;
  for I := 0 to Pred(VertexCount) do
    Queue.Enqueue(I, TSbWNode.Create(I, AdjLists[I]^.Count, AdjLists[I]^.Count));
  InQueue.InitRange(VertexCount);
  I := 0;
  while Queue.TryDequeue(Item) do
    begin
      List[I] := Item.Index;
      Inc(I);
      InQueue.UncBits[Item.Index] := False;
      for p in AdjLists[Item.Index]^ do
        if InQueue.UncBits[p^.Key] then
          with Queue.GetItemPtr(p^.Key)^ do
            Queue.Update(p^.Key, TSbWNode.Create(Index, Pred(WDegree), Degree));
    end;
  if o = soDesc then
    TIntHelper.Reverse(List);
  Result := List;
end;

function TGSimpleGraph.SortComplementByWidth: TIntArray;
  procedure CommSort;
  var
    List, Stack: TIntSet;
    vList: TIntArray;
    I, J: SizeInt;
  begin
    vList := CreateComplementDegreeArray;
    List.InitRange(VertexCount);
    while List.NonEmpty do
      begin
        I := List[0];
        for J in List do
          if vList[J] < vList[I] then
            I := J;
        {%H-}Stack.Push(I);
        List.Remove(I);
        for J in List do
          if not AdjLists[I]^.Contains(J) then
            Dec(Result[J]);
      end;
    Result := Stack.ToArray;
    TIntHelper.Reverse(Result);
  end;
  procedure BpSort;
  var
    Queue: specialize TGPairHeapMin<TSbWNode>;
    m: TBoolMatrix;
    List: TIntArray = nil;
    InQueue: TBoolVector;
    Item: TSbWNode = (Index: -1; WDegree: -1; Degree: -1;);
    I, J: SizeInt;
    p: PAdjItem;
  begin
    System.SetLength(m, VertexCount);
    for I := 0 to Pred(VertexCount) do //create complement matrix
      begin
        m[I].InitRange(VertexCount);
        m[I].UncBits[I] := False;
        for p in AdjLists[I]^ do
          m[I].UncBits[p^.Key] := False;
      end;
    Queue := specialize TGPairHeapMin<TSbWNode>.Create(VertexCount);
    List.Length := VertexCount;
    for I := 0 to Pred(VertexCount) do
      begin
        J := m[I].PopCount;
        Queue.Enqueue(I, TSbWNode.Create(I, J, J));
      end;
    InQueue.InitRange(VertexCount);
    I := 0;
    while Queue.TryDequeue(Item) do
      begin
        List[I] := Item.Index;
        Inc(I);
        InQueue.UncBits[Item.Index] := False;
        for J in m[Item.Index] do
          if InQueue.UncBits[J] then
            with Queue.GetItemPtr(J)^ do
              Queue.Update(J, TSbWNode.Create(Index, Pred(WDegree), Degree));
      end;
    TIntHelper.Reverse(List);
    Result := List;
  end;

begin
  Result := nil;
  if VertexCount > COMMON_BP_CUTOFF then
    CommSort
  else
    BpSort;
end;

function TGSimpleGraph.SortNodesByDegree(o: TSortOrder): TIntArray;
begin
  Result := CreateIntArrayRange;
  TSortByDegreeHelper.Sort(Result, @CmpByDegree, o);
end;

function TGSimpleGraph.CmpByDegree(const L, R: SizeInt): Boolean;
begin
  Result := AdjLists[L]^.Count < AdjLists[R]^.Count;
end;

function TGSimpleGraph.CmpIntArrayLen(const L, R: TIntArray): Boolean;
begin
  Result := System.Length(L) < System.Length(R);
end;

function TGSimpleGraph.DoAddVertex(const aVertex: TVertex; out aIndex: SizeInt): Boolean;
begin
  Result := not FindOrAdd(aVertex, aIndex);
  if not Result then
    exit;
  if ConnectedValid then
    begin
      FNodeList[aIndex].Tag := aIndex;
      Inc(FCompCount);
      FConnected := FCompCount = 1;
    end
  else
    FNodeList[aIndex].Tag := FCompCount;
end;

procedure TGSimpleGraph.DoRemoveVertex(aIndex: SizeInt);
var
  CurrEdges: TAdjList.TAdjItemArray;
  I, J: SizeInt;
begin
  FEdgeCount -= FNodeList[aIndex].AdjList.Count;
  Delete(aIndex);
  FConnectedValid := False;
  for I := 0 to Pred(VertexCount) do
    begin
      CurrEdges := FNodeList[I].AdjList.ToArray;
      FNodeList[I].AdjList.MakeEmpty;
      for J := 0 to System.High(CurrEdges) do
        if CurrEdges[J].Destination <> aIndex then
          begin
            if CurrEdges[J].Destination > aIndex then
              Dec(CurrEdges[J].Destination);
            FNodeList[I].AdjList.Add(CurrEdges[J]);
          end;
    end;
end;

function TGSimpleGraph.DoAddEdge(aSrc, aDst: SizeInt; const aData: TEdgeData): Boolean;
begin
  Result := not (aSrc = aDst) and FNodeList[aSrc].AdjList.Add(TAdjItem.Create(aDst, aData));
  if Result then
    begin
      if FNodeList[aDst].AdjList.Add(TAdjItem.Create(aSrc, aData)) then
        begin
          Inc(FEdgeCount);
          if ConnectedValid and SeparateJoin(aSrc, aDst) then
            begin
              Dec(FCompCount);
              FConnected := FCompCount = 1;
            end;
        end
      else
        raise EGraphError.Create(SEInternalDataInconsist);
    end;
end;

function TGSimpleGraph.DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
begin
  Result := FNodeList[aSrc].AdjList.Remove(aDst);
  if Result then
    begin
      FNodeList[aDst].AdjList.Remove(aSrc);
      Dec(FEdgeCount);
      FConnectedValid := False;
    end;
end;

function TGSimpleGraph.DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeData): Boolean;
var
  p: PAdjItem;
begin
  p := AdjLists[aSrc]^.Find(aDst);
  Result := p <> nil;
  if Result then
    begin
      p^.Data := aValue;
      AdjLists[aDst]^.Find(aSrc)^.Data := aValue;
    end;
end;

procedure TGSimpleGraph.DoWriteEdges(aStream: TStream; aOnWriteData: TOnWriteData);
var
  s, d: Integer;
  e: TEdge;
begin
  for e in {%H-}DistinctEdges do
    begin
      s := e.Source;
      d := e.Destination;
      aStream.WriteBuffer(NtoLE(s), SizeOf(s));
      aStream.WriteBuffer(NtoLE(d), SizeOf(d));
      aOnWriteData(aStream, e.Data);
    end;
end;

procedure TGSimpleGraph.EdgeContracting(aSrc, aDst: SizeInt);
var
  ToRemove: TIntArray = nil;
  I, RemoveCount: SizeInt;
  p: PAdjItem;
begin
  //there edge aSrc -- aDst already removed
  if AdjLists[aDst]^.Count = 0 then
    exit;
  ToRemove.Length := AdjLists[aDst]^.Count;
  RemoveCount := 0;
  for p in AdjLists[aDst]^ do
    if DoAddEdge(aSrc, p^.Destination, p^.Data) then
      AdjLists[p^.Destination]^.Remove(aDst)
    else
      begin
        ToRemove[RemoveCount] := p^.Destination;
        Inc(RemoveCount);
      end;
  for I := 0 to Pred(RemoveCount) do
    DoRemoveEdge(aDst, ToRemove[I]);
  Dec(FEdgeCount, AdjLists[aDst]^.Count);
  AdjLists[aDst]^.MakeEmpty;
end;

class function TGSimpleGraph.MayBeIsomorphic(L, R: TGSimpleGraph): Boolean;
var
  I, J: SizeInt;
begin
  if L.IsEmpty then
    exit(R.IsEmpty)
  else
    if R.IsEmpty then
      exit(False);
  if (L.VertexCount <> R.VertexCount) or (L.EdgeCount <> R.EdgeCount) or
     (L.SeparateCount <> R.SeparateCount) then
    exit(False);
  if L.IsRegular(I) then
    begin
      if not R.IsRegular(J) then
        exit(False);
      if I <> J then
        exit(False);
      if not TIntHelper.Same(L.GetCycleBasisVector, R.GetCycleBasisVector) then
        exit(False);
    end
  else
    begin
      if not TIntHelper.Same(L.CreateDegreeVector, R.CreateDegreeVector) then
        exit(False);
      if not TIntHelper.Same(L.CreateNeighDegreeVector, R.CreateNeighDegreeVector) then
        exit(False);
    end;
  Result := True;
end;

constructor TGSimpleGraph.Create;
begin
  inherited;
  FConnectedValid := True;
end;

procedure TGSimpleGraph.Clear;
begin
  inherited;
  FCompCount := 0;
  FConnected := False;
  FConnectedValid := True;
end;

function TGSimpleGraph.Clone: TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignGraph(Self);
end;

function TGSimpleGraph.SeparateGraph(const aVertex: TVertex): TGSimpleGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self)
end;

function TGSimpleGraph.InducedSubgraph(const aVertexList: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGSimpleGraph.SubgraphFromTree(const aTree: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGSimpleGraph.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGSimpleGraph.CreatePermutation(const aMap: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignPermutation(Self, aMap);
end;

function TGSimpleGraph.CreateLineGraph: TLineGraph;
var
  I, J: SizeInt;
  vI, vJ: TOrdIntPair;
  e: TEdge;
begin
  Result := TLineGraph.Create;
  Result.EnsureCapacity(EdgeCount);
  for e in {%H-}DistinctEdges do
    {%H-}Result.AddVertex(TOrdIntPair.Create(e.Source, e.Destination));
  for I := 0 to Result.VertexCount - 2 do
    begin
      vI := Result[I];
      for J := Succ(I) to Pred(Result.VertexCount) do
        begin
          vJ := Result[J];
          if (vI.Left = vJ.Left) or (vI.Left = vJ.Right) then
            Result.AddEdgeI(I, J, TIntValue.Create(vI.Left))
          else
            if (vI.Right = vJ.Left) or (vI.Right = vJ.Right) then
               Result.AddEdgeI(I, J, TIntValue.Create(vI.Right))
        end;
    end;
end;

procedure TGSimpleGraph.SetSymmDifferenceOf(aGraph: TGSimpleGraph);
var
  Tmp: TGSimpleGraph;
  e: TEdge;
  s, d: TVertex;
begin
  Tmp := TGSimpleGraph.Create;
  try
    Tmp.Title := Title;
    Tmp.Description := Description;
    for e in DistinctEdges do
      begin
        s := Items[e.Source];
        d := Items[e.Destination];
        if not aGraph.ContainsEdge(s, d) then
          Tmp.AddEdge(s, d, e.Data);
      end;
    for e in aGraph.DistinctEdges do
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

function TGSimpleGraph.Degree(const aVertex: TVertex): SizeInt;
begin
  Result := DegreeI(IndexOf(aVertex));
end;

function TGSimpleGraph.DegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].AdjList.Count;
end;

function TGSimpleGraph.Isolated(const aVertex: TVertex): Boolean;
begin
  Result := Degree(aVertex) = 0;
end;

function TGSimpleGraph.IsolatedI(aIndex: SizeInt): Boolean;
begin
  Result := DegreeI(aIndex) = 0;
end;

function TGSimpleGraph.DistinctEdges: TDistinctEdges;
begin
  Result.FGraph := Self;
end;

function TGSimpleGraph.CreateComplementMatrix: TAdjacencyMatrix;
var
  m: TSquareBitMatrix;
  I: SizeInt;
  p: PAdjItem;
begin
  if IsEmpty then
    exit(Default(TAdjacencyMatrix));
  m := TSquareBitMatrix.CreateAndSet(VertexCount);
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      m[I, p^.Destination] := False;
  Result := TAdjacencyMatrix.Create(m);
end;

function TGSimpleGraph.EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := 0;
  if VertexCount < 2 then
    exit;
  if SeparateCount < 2 then
    exit;
  Result := MakeConnected(aOnAddEdge);
end;

function TGSimpleGraph.PathExists(const aSrc, aDst: TVertex): Boolean;
begin
  Result := PathExistsI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.PathExistsI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(True);
  if SeparateCount > 1 then
    Result := SeparateTag(aSrc) = SeparateTag(aDst)
  else
    Result := True;
end;

function TGSimpleGraph.SeparatePop(const aVertex: TVertex): SizeInt;
begin
  Result := SeparatePopI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparatePopI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  if SeparateCount > 1 then
    Result := CountPop(SeparateTag(aIndex))
  else
    Result := VertexCount;
end;

function TGSimpleGraph.GetSeparate(const aVertex: TVertex): TIntArray;
begin
  Result := GetSeparateI(IndexOf(aVertex));
end;

function TGSimpleGraph.GetSeparateI(aIndex: SizeInt): TIntArray;
var
  I, J, Tag: SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := nil;
  if SeparateCount > 1 then
    begin
      Result.Length := VertexCount;
      Tag := SeparateTag(aIndex);
      J := 0;
      for I := 0 to Pred(VertexCount) do
        if SeparateTag(I) = Tag then
          begin
            Result[J] := I;
            Inc(J);
          end;
      Result.Length := J;
    end
  else
    Result := CreateIntArrayRange;
end;

function TGSimpleGraph.FindSeparates: TIntVectorArray;
var
  Tags: TIntArray;
  CurrIndex, CurrTag, I: SizeInt;
begin
  if IsEmpty then
    exit(nil);
  Tags := CreateIntArray;
  CurrIndex := NULL_INDEX;
  System.SetLength(Result, SeparateCount);
  for I := 0 to Pred(VertexCount) do
    begin
      CurrTag := SeparateTag(I);
      if Tags[CurrTag] = NULL_INDEX then
        begin
          Inc(CurrIndex);
          Tags[CurrTag] := CurrIndex;
        end;
      Result[Tags[CurrTag]].Add(I);
    end;
end;

function TGSimpleGraph.IsTree: Boolean;
begin
  Result := (EdgeCount = Pred(VertexCount)) and Connected;
end;

function TGSimpleGraph.IsStar(out aHub: SizeInt): Boolean;
var
  I, d: SizeInt;
begin
  if (VertexCount < 4) or not IsTree then
    exit(False);
  aHub := NULL_INDEX;
  for I := 0 to Pred(VertexCount) do
    begin
      d := AdjLists[I]^.Count;
      if d = 1 then
        continue;
      if d <> Pred(VertexCount) then
        exit(False);
      aHub := I;
    end;
  Result := True;
end;

function TGSimpleGraph.IsCycle: Boolean;
var
  d: SizeInt;
begin
  if (VertexCount >= 3) and (VertexCount = EdgeCount) and Connected and IsRegular(d) then
    Result := d = 2
  else
    Result := False;
end;

function TGSimpleGraph.IsWheel(out aHub: SizeInt): Boolean;
var
  I, d: SizeInt;
begin
  aHub := NULL_INDEX;
  if (VertexCount >= 4) and (EdgeCount = Pred(VertexCount) shl 1) and Connected then
    begin
      for I := 0 to Pred(VertexCount) do
        begin
          d := AdjLists[I]^.Count;
          if d = 3 then
            continue;
          if d <> Pred(VertexCount) then
            exit(False);
          aHub := I;
        end;
      if aHub = NULL_INDEX then
        aHub := 0;
      Result := True;
    end
  else
    Result := False;
end;

function TGSimpleGraph.IsComplete: Boolean;
begin
  if Connected then
    Result := (EdgeCount shl 1) div VertexCount = Pred(VertexCount)
  else
    Result := False;
end;

function TGSimpleGraph.IsRegular(out aDegree: SizeInt): Boolean;
var
  I: SizeInt;
begin
  aDegree := NULL_INDEX;
  if NonEmpty then
    begin
      aDegree := AdjLists[0]^.Count;
      for I := 1 to Pred(VertexCount) do
        if AdjLists[I]^.Count <> aDegree then
          begin
            aDegree := NULL_INDEX;
            exit(False);
          end;
    end;
  Result := True;
end;

function TGSimpleGraph.IsChordal(out aRevPeo: TIntArray): Boolean;
begin
  if VertexCount < 4 then
    exit(True);
  Result := FindPerfectElimOrd(nil, aRevPeo);
end;

function TGSimpleGraph.IsPlanar: Boolean;
var
  Helper: TPlanarHelper;
begin
  if (VertexCount > 4) and (EdgeCount > VertexCount * 3 - 6) then
    exit(False);
  if VertexCount > 4 then
    Result := Helper.GraphIsPlanar(Self)
  else
    Result := True;
end;

function TGSimpleGraph.IsPlanarR: Boolean;
var
  Helper: TPlanarHelper;
begin
  if (VertexCount > 4) and (EdgeCount > VertexCount * 3 - 6) then
    exit(False);
  if VertexCount > 4 then
    Result := Helper.GraphIsPlanarR(Self)
  else
    Result := True;
end;

function TGSimpleGraph.IsPlanar(out aEmbedding: TPlanarEmbedding): Boolean;
var
  Helper: TPlanarHelper;
begin
  aEmbedding := Default(TPlanarEmbedding);
  Result := True;
  if IsEmpty then
    exit;
  if VertexCount < 3 then
    begin
      if VertexCount = 1 then
        aEmbedding.Init1
      else
        aEmbedding.Init2(Connected);
      exit;
    end;
  if (VertexCount > 2) and (EdgeCount > VertexCount * 3 - 6) then
    exit(False);
  Result := Helper.GraphIsPlanar(Self, aEmbedding);
end;

function TGSimpleGraph.IsPlanarR(out aEmbedding: TPlanarEmbedding): Boolean;
var
  Helper: TPlanarHelper;
begin
  aEmbedding := Default(TPlanarEmbedding);
  Result := True;
  if IsEmpty then
    exit;
  if VertexCount < 3 then
    begin
      if VertexCount = 1 then
        aEmbedding.Init1
      else
        aEmbedding.Init2(Connected);
      exit;
    end;
  if (VertexCount > 2) and (EdgeCount > VertexCount * 3 - 6) then
    exit(False);
  Result := Helper.GraphIsPlanarR(Self, aEmbedding);
end;

function TGSimpleGraph.IsEmbedding(const aEmbedding: TPlanarEmbedding): Boolean;
var
  eSet: TIntEdgeHashSet;
  FaceOk: Boolean;
  procedure OnPass(aSrc, aDst: SizeInt);
  begin
    FaceOk := FaceOk and ContainsEdgeI(aSrc, aDst);
    if FaceOk then
      FaceOk := FaceOk and eSet.Add(TIntEdge.Create(aSrc, aDst));
  end;
var
  I, J, Cnt, Comp, NodeCnt, EdgeCnt, FaceCnt: SizeInt;
  AdjList: PAdjList;
begin
  if (aEmbedding.NodeCount <> VertexCount) or (aEmbedding.EdgeCount <> EdgeCount) then
    exit(False);
  if aEmbedding.ComponentCount <> SeparateCount then
    exit(False);
  Cnt := 0;
  for I := 0 to Pred(aEmbedding.ComponentCount) do
    Cnt += aEmbedding.ComponentPop[I];
  if Cnt <> aEmbedding.NodeCount then
    exit(False);

  for I := 0 to Pred(VertexCount) do
    begin
      AdjList := AdjLists[I];
      Cnt := 0;
      for J in aEmbedding.AdjListCw(I) do
        begin
          if not AdjList^.Contains(J) then
            exit(False);
          Inc(Cnt);
        end;
      if AdjList^.Count <> Cnt then
        exit(False);
    end;

  for Comp := 0 to Pred(aEmbedding.ComponentCount) do
    begin
      NodeCnt := aEmbedding.ComponentPop[Comp];
      if NodeCnt < 2 then
        continue;
      FaceCnt := 0;
      EdgeCnt := 0;
      for I in aEmbedding[Comp] do
        for J in aEmbedding.AdjListCw(I) do
          begin
            Inc(EdgeCnt);
            if not eSet.Contains(TIntEdge.Create(I, J)) then
              begin
                Inc(FaceCnt);
                FaceOk := True;
                aEmbedding.TraverseFace(TIntEdge.Create(I, J), @OnPass);
                if not FaceOk then
                  exit(False);
              end;
          end;
      if Odd(EdgeCnt) then
        exit(False);
      //check if FaceCnt satisfies Euler's formula
      if not NodeCnt + FaceCnt - EdgeCnt div 2 = 2 then
        exit(False);
    end;

  Result := True;
end;

function TGSimpleGraph.Degeneracy: SizeInt;
var
  Queue: TINodePqMin;
  InQueue: TBoolVector;
  Item: TIntNode = (Index: -1; Data: -1);
  I: SizeInt;
  p: PAdjItem;
begin
  if IsEmpty then
    exit(NULL_INDEX);
  Result := 0;
  Queue := TINodePqMin.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    Queue.Enqueue(I, TIntNode.Create(I, AdjLists[I]^.Count));
  InQueue.InitRange(VertexCount);
  while Queue.TryDequeue(Item) do
    begin
      if Item.Data > Result then
        Result := Item.Data;
      InQueue.UncBits[Item.Index] := False;
      for p in AdjLists[Item.Index]^ do
        if InQueue.UncBits[p^.Key] then
          Queue.Update(p^.Key, TIntNode.Create(p^.Key, Pred(Queue.GetItemPtr(p^.Key)^.Data)));
    end;
end;

function TGSimpleGraph.Degeneracy(out aDegs: TIntArray): SizeInt;
var
  Queue: TINodePqMin;
  InQueue: TBoolVector;
  Item: TIntNode = (Index: -1; Data: -1);
  I: SizeInt;
  p: PAdjItem;
begin
  aDegs := nil;
  if IsEmpty then
    exit(NULL_INDEX);
  Result := 0;
  Queue := TINodePqMin.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    Queue.Enqueue(I, TIntNode.Create(I, AdjLists[I]^.Count));
  InQueue.InitRange(VertexCount);
  aDegs.Length := VertexCount;
  while Queue.TryDequeue(Item) do
    begin
      if Item.Data > Result then
        Result := Item.Data;
      aDegs[Item.Index] := Result;
      InQueue.UncBits[Item.Index] := False;
      for p in AdjLists[Item.Index]^ do
        if InQueue.UncBits[p^.Key] then
          Queue.Update(p^.Key, TIntNode.Create(p^.Key, Pred(Queue.GetItemPtr(p^.Key)^.Data)));
    end;
end;

function TGSimpleGraph.KCore(aK: SizeInt): TIntArray;
var
  Queue: TINodePqMin;
  InQueue: TBoolVector;
  Item: TIntNode = (Index: -1; Data: -1);
  I: SizeInt;
  p: PAdjItem;
begin
  if IsEmpty then
    exit(nil);
  if aK <= 0 then
    exit(CreateIntArrayRange);
  Queue := TINodePqMin.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    Queue.Enqueue(I, TIntNode.Create(I, AdjLists[I]^.Count));
  InQueue.InitRange(VertexCount);
  while Queue.TryDequeue(Item) do
    begin
      if Item.Data >= aK then
        break;
      InQueue.UncBits[Item.Index] := False;
      for p in AdjLists[Item.Index]^ do
        if InQueue.UncBits[p^.Key] then
          Queue.Update(p^.Key, TIntNode.Create(p^.Key, Pred(Queue.GetItemPtr(p^.Key)^.Data)));
    end;
  Result := InQueue.ToArray;
end;

function TGSimpleGraph.LocalClustering(const aVertex: TVertex): ValReal;
begin
  Result := LocalClusteringI(IndexOf(aVertex));
end;

function TGSimpleGraph.LocalClusteringI(aIndex: SizeInt): Double;
var
  I, J, Counter, d: SizeInt;
  pList: PAdjList;
begin
  CheckIndexRange(aIndex);
  d := DegreeI(aIndex);
  if d <= 1 then
    exit(0.0);
  Counter := 0;
  for I in AdjVerticesI(aIndex) do
    begin
      pList := AdjLists[I];
      for J in AdjVerticesI(aIndex) do
        if I <> J then
          Counter += Ord(pList^.Contains(J));
    end;
  Result := Double(Counter) / (Double(d) * Double(Pred(d)));
end;

function TGSimpleGraph.CyclomaticNumber: SizeInt;
begin
  Result := EdgeCount - VertexCount + SeparateCount;
end;

function TGSimpleGraph.ContainsCycle(const aVertex: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsCycleI(IndexOf(aVertex), aCycle);
end;

function TGSimpleGraph.ContainsCycleI(aIndex: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aIndex);
  if VertexCount < 3 then
    exit(False);
  if ConnectedValid and IsTree then
    exit(False);
  Result := CycleExists(aIndex, aCycle);
end;

function TGSimpleGraph.IsAcyclic: Boolean;
begin
  if VertexCount < 3 then
    exit(True);
  if ConnectedValid and Connected then
    exit(IsTree);
  Result := CheckAcyclic;
end;

function TGSimpleGraph.ContainsEulerianPath(out aFirstOdd: SizeInt): Boolean;
var
  Comps: TIntVectorArray;
  I, Cand, OddCount: SizeInt;
begin
  aFirstOdd := NULL_INDEX;
  if VertexCount < 2 then
    exit(False);
  Comps := FindSeparates;
  Cand := NULL_INDEX;
  for I := 0 to System.High(Comps) do
    if Comps[I].Count > 1 then
      if Cand = NULL_INDEX then
        Cand := I
      else
        exit(False);
  if Cand = NULL_INDEX then
    exit(False);
  OddCount := 0;
  for I in Comps[Cand] do
    if Odd(AdjLists[I]^.Count) then
      begin
        Inc(OddCount);
        if OddCount > 2 then
          begin
            aFirstOdd := NULL_INDEX;
            exit(False);
          end;
        if aFirstOdd = NULL_INDEX then
          aFirstOdd := I;
      end;
  Result := True;
end;

function TGSimpleGraph.ContainsEulerianCycle: Boolean;
var
  Comps: TIntVectorArray;
  I, Cand: SizeInt;
begin
  if VertexCount < 3 then
    exit(False);
  Comps := FindSeparates;
  Cand := NULL_INDEX;
  for I := 0 to System.High(Comps) do
    if Comps[I].Count > 1 then
      if Cand = NULL_INDEX then
        Cand := I
      else
        exit(False);
  if Cand = NULL_INDEX then
    exit(False);
  for I in Comps[Cand] do
    if Odd(AdjLists[I]^.Count) then
      exit(False);
  Result := True;
end;

function TGSimpleGraph.FindEulerianCycle: TIntArray;
var
  g: TSkeleton;
  Stack: TIntStack;
  s, d: SizeInt;
begin
  if not ContainsEulerianCycle then
    exit(nil);
  g := CreateSkeleton;
  s := 0;
  while g.Degree[s] = 0 do
    Inc(s);
  {%H-}Stack.Push(s);
  while g[s]^.FindFirst(d) do
    begin
      g.RemoveEdge(s, d);
      Stack.Push(d);
      s := d;
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.FindEulerianPath: TIntArray;
var
  g: TSkeleton;
  Stack, Path: TIntStack;
  s, d: SizeInt;
begin
  if not ContainsEulerianPath(s) then
    exit(nil);
  g := CreateSkeleton;
  if s = NULL_INDEX then
    begin
      s := 0;
      while g.Degree[s] = 0 do
        Inc(s);
    end;
  {%H-}Stack.Push(s);
  while Stack.TryPeek(s) do
    if g[s]^.FindFirst(d) then
      begin
        g.RemoveEdge(s, d);
        Stack.Push(d);
      end
    else
      {%H-}Path.Push(Stack.Pop{%H-});
  Result := Path.ToArray;
end;

function TGSimpleGraph.FindFundamentalCycles: TIntArrayVector;
begin
  Result := Default(TIntArrayVector);
  if IsTree then
    exit;
  SearchForCycleBasis(Result);
  if Result.Count <> CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  TIntArrayVectorHelper.Sort(Result, @CmpIntArrayLen);
end;

function TGSimpleGraph.ContainsCutVertex(const aVertex: TVertex): Boolean;
begin
  Result := ContainsCutVertexI(IndexOf(aVertex));
end;

function TGSimpleGraph.ContainsCutVertexI(aIndex: SizeInt): Boolean;
begin
  CheckIndexRange(aIndex);
  if VertexCount < 3 then
    exit(False);
  Result := CutVertexExists(aIndex);
end;

function TGSimpleGraph.FindCutVertices(const aVertex: TVertex): TIntArray;
begin
  Result := FindCutVerticesI(IndexOf(aVertex));
end;

function TGSimpleGraph.FindCutVerticesI(aIndex: SizeInt): TIntArray;
var
  v: TIntHashSet;
begin
  CheckIndexRange(aIndex);
  v := Default(TIntHashSet);
  if VertexCount > 2 then
    begin
      SearchForCutVertices(aIndex, v);
      Result := v.ToArray;
    end
  else
    Result := nil;
end;

function TGSimpleGraph.RemoveCutVertices(const aVertex: TVertex; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := RemoveCutVerticesI(IndexOf(aVertex), aOnAddEdge);
end;

function TGSimpleGraph.RemoveCutVerticesI(aIndex: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := 0;
  CheckIndexRange(aIndex);
  NewEdges := Default(TIntEdgeVector);
  if VertexCount < 3 then
    exit;
  SearchForBiconnect(aIndex, NewEdges{%H-});
  d := Default(TEdgeData);
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(FNodeList[e.Source].Vertex, FNodeList[e.Destination].Vertex, d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.ContainsBridge: Boolean;
begin
  if VertexCount > 1 then
    Result := BridgeExists
  else
    Result := False;
end;

function TGSimpleGraph.FindBridges: TIntEdgeArray;
var
  v: TIntEdgeVector;
begin
  v := Default(TIntEdgeVector);
  if VertexCount > 1 then
    SearchForBridges(v);
  Result := v.ToArray;
end;

function TGSimpleGraph.IsBiconnected: Boolean;
begin
  if Connected then
    Result := not ContainsCutVertexI(0)
  else
    Result := False;
end;

procedure TGSimpleGraph.FindBicomponents(const aVertex: TVertex; out aComps: TEdgeArrayVector);
begin
  FindBicomponentsI(IndexOf(aVertex), aComps);
end;

procedure TGSimpleGraph.FindBicomponentsI(aIndex: SizeInt; out aComps: TEdgeArrayVector);
begin
  aComps := Default(TEdgeArrayVector);
  CheckIndexRange(aIndex);
  if VertexCount > 2 then
    SearchForBicomponent(aIndex, aComps)
  else
    if (VertexCount = 2) and ContainsEdgeI(0, 1) then
      aComps.Add([TIntEdge.Create(0, 1)]);
end;

function TGSimpleGraph.EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := EnsureConnected(aOnAddEdge);
  if VertexCount < 3 then
    exit;
  NewEdges := Default(TIntEdgeVector);
  SearchForBiconnect(0, NewEdges);
  d := Default(TEdgeData);
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(Items[e.Source], Items[e.Destination], d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.FindMetrics(out aRadius, aDiameter: SizeInt): Boolean;
begin
  Result := Connected;
  if Result then
    DoFindMetrics(aRadius, aDiameter);
end;

function TGSimpleGraph.FindCenter: TIntArray;
var
  Eccs: TIntArray;
  I, J, Radius, Diam: SizeInt;
begin
  Result := nil;
  if not Connected then
    exit;
  Eccs := DoFindMetrics(Radius, Diam);
  Result{%H-}.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] = Radius then
      begin
        Result[J] := I;
        Inc(J);
      end;
  Result.Length := J;
end;

function TGSimpleGraph.FindPeripheral: TIntArray;
var
  Eccs: TIntArray;
  I, J, Radius, Diam: SizeInt;
begin
  Result := nil;
  if not Connected then
    exit;
  Eccs := DoFindMetrics(Radius, Diam);
  Result{%H-}.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] = Diam then
      begin
        Result[J] := I;
        Inc(J);
      end;
  Result.Length := J;
end;

function TGSimpleGraph.ShortestPath(const aSrc, aDst: TVertex): TIntArray;
begin
  Result := ShortestPathI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.ShortestPathI(aSrc, aDst: SizeInt): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(nil);
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    exit(nil);
  Result := GetShortestPath(aSrc, aDst);
end;

function TGSimpleGraph.MinCut: SizeInt;
var
  Helper: TNISimpMinCutHelper;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    exit(1);
  Result := Helper.Execute(Self);
end;

function TGSimpleGraph.MinCut(out aCut: TCut): SizeInt;
var
  Helper: TNISimpMinCutHelper;
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    begin
      aCut.A := [0];
      aCut.B := [1];
      exit(1);
    end;
  Result := Helper.Execute(Self, Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B.UncBits[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
end;

function TGSimpleGraph.MinCut(out aCut: TCut; out aCrossEdges: TIntEdgeArray): SizeInt;
var
  Left, Right: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
begin
  Result := MinCut(aCut);
  if Result < 1 then
    begin
      aCrossEdges := nil;
      exit;
    end;
  if aCut.A.Length <= aCut.B.Length then
    begin
      Left.Capacity := VertexCount;
      Right.InitRange(VertexCount);
      for I in aCut.A do
        begin
          Left.UncBits[I] := True;
          Right.UncBits[I] := False;
        end;
    end
  else
    begin
      Right.Capacity := VertexCount;
      Left.InitRange(VertexCount);
      for I in aCut.B do
        begin
          Right.UncBits[I] := True;
          Left.UncBits[I] := False;
        end;
    end;
  J := 0;
  System.SetLength(aCrossEdges, Result);
  for I in Left do
    for p in AdjLists[I]^ do
      if Right.UncBits[p^.Destination] then
        begin
          if I < p^.Destination then
            aCrossEdges[J] := TIntEdge.Create(I, p^.Destination)
          else
            aCrossEdges[J] := TIntEdge.Create(p^.Destination, I);
          Inc(J);
        end;
end;

function TGSimpleGraph.FindMaxBipMatchHK(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: THKMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.MaxMatching(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.GetMaxBipMatchHK(const aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: THKMatch;
begin
  Result := Helper.MaxMatching(Self, aWhites, aGrays);
end;

function TGSimpleGraph.FindMaxBipMatchBfs(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: TBfsMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.MaxMatching(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.GetMaxBipMatchBfs(const aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: TBfsMatch;
begin
  Result := Helper.MaxMatching(Self, aWhites, aGrays);
end;

function TGSimpleGraph.GreedyMaxMatch: TIntEdgeArray;
begin
  if VertexCount < 2 then
    exit(nil);
  if (VertexCount = 2) and Connected then
    exit([TIntEdge.Create(0, 1)]);
  Result := GreedyMatching2;
end;

function TGSimpleGraph.FindMaxMatchEd: TIntEdgeArray;
var
  Helper: TEdMatchHelper;
begin
  if VertexCount < 2 then
    exit(nil);
  Result := Helper.Execute(Self);
end;

function TGSimpleGraph.FindMaxMatchPC: TIntEdgeArray;
var
  Helper: TPcMatchHelper;
begin
  if VertexCount < 2 then
    exit(nil);
  Result := Helper.Execute(Self);
end;

procedure TGSimpleGraph.ListAllMIS(aOnFound: TOnSetFound);
begin
  if IsEmpty then
    exit;
  if aOnFound = nil then
    raise EGraphError.Create(SECallbackMissed);
  if VertexCount > TBits256.BITNESS then
    ListIsBP(aOnFound)
  else
    ListIsBP256(aOnFound);
end;

function TGSimpleGraph.FindMIS(out aExact: Boolean; aTimeOut: Integer): TIntArray;
begin
  aExact := True;
  if IsEmpty then
    exit(nil);
  if Connected then
    Result := GetMisConnected(aTimeOut, aExact)
  else
    Result := GetMisDisconnected(aTimeOut, aExact)
end;

function TGSimpleGraph.GreedyMIS: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetGreedyMis
  else
    Result := GetGreedyMisBP;
end;

function TGSimpleGraph.IsMIS(const aTestMis: TIntArray): Boolean;
var
  TestIS, Remain: TBoolVector;
  I, J: SizeInt;
  AdjList: PAdjList;
  AdjFound: Boolean;
begin
  if IsEmpty then
    exit(aTestMis.IsEmpty);
  TestIS.Capacity := VertexCount;
  for I in aTestMis do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestIS.UncBits[I] then  //contains duplicates -> is not set
        exit(False);
      TestIS.UncBits[I] := True;
    end;
  for I in aTestMis do
    begin
      AdjList := AdjLists[I];
      for J in aTestMis do
        if AdjList^.Contains(J) then //contains adjacent vertices -> is not independent
          exit(False);
    end;
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestIS);
  Finalize(TestIS);
  for I in Remain do
    begin
      AdjFound := False;
      AdjList := AdjLists[I];
      for J in aTestMis do
        if AdjList^.Contains(J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then //I can be added to aTestMis -> aTestMis is not maximal
        exit(False);
    end;
  Result := True;
end;

procedure TGSimpleGraph.ListDomSets(AtMostSize: SizeInt; aOnFound: TOnSetFound);
begin
  if IsEmpty then
    exit;
  if aOnFound = nil then
    raise EGraphError.Create(SECallbackMissed);
  DoListDomSets(AtMostSize, aOnFound);
end;

function TGSimpleGraph.FindMDS(out aExact: Boolean; aTimeOut: Integer): TIntArray;
begin
  aExact := True;
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0])
  else
    if VertexCount = 2 then
      if Connected then
        exit([0])
      else
        exit([0, 1]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetMds(aTimeOut, aExact)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMdsBP(aTimeOut, aExact)
    else
      Result := GetMdsBP256(aTimeOut, aExact);
end;

function TGSimpleGraph.GreedyMDS: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0])
  else
    if VertexCount = 2 then
      if Connected then
        exit([0])
      else
        exit([0, 1]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetGreedyMinIs
  else
    Result := GetGreedyMinIsBP;
end;

function TGSimpleGraph.IsMDS(const aTestMds: TIntArray): Boolean;
var
  TestMds, Remain: TBoolVector;
  I, J, K: SizeInt;
  AdjList: PAdjList;
  AdjFound: Boolean;
begin
  if IsEmpty then
    exit(aTestMds.IsEmpty);
  if System.Length(aTestMds) = 0 then
    exit(False);
  TestMds.Capacity := VertexCount;
  for I in aTestMds do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestMds.UncBits[I] then         //contains duplicates -> is not set
        exit(False);
      TestMds.UncBits[I] := True;
    end;
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestMds);
  Finalize(TestMds);
  for I in Remain do
    begin
      AdjList := AdjLists[I];
      AdjFound := False;
      for J in aTestMds do
        if AdjList^.Contains(J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then      //is not dominating set
        exit(False);
    end;

  for I in aTestMds do
    begin
      Remain.UncBits[I] := True; //test aTestMds without I
      for K in Remain do
        begin
          AdjList := AdjLists[K];
          AdjFound := False;
          for J in aTestMds do
            if (J <> I) and AdjList^.Contains(J) then
              begin
                AdjFound := True;
                break;
              end;
          if not AdjFound then //exists vertex nonadjacent with aTestMds without I
            break;
        end;
      if AdjFound then         //is not minimal
        exit(False);
      Remain.UncBits[I] := False;
    end;
  Result := True;
end;

procedure TGSimpleGraph.ListAllCliques(aOnFound: TOnSetFound);
begin
  if IsEmpty then
    exit;
  if aOnFound = nil then
    raise EGraphError.Create(SECallbackMissed);
  if (VertexCount > LISTCLIQUES_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    ListCliques(aOnFound)
  else
    if VertexCount > TBits256.BITNESS then
      ListCliquesBP(aOnFound)
    else
      ListCliquesBP256(aOnFound);
end;

function TGSimpleGraph.FindMaxClique(out aExact: Boolean; aTimeOut: Integer): TIntArray;
begin
  aExact := True;
  if IsEmpty then
    exit(nil);
  if Connected then
    Result := GetMaxCliqueConnected(aTimeOut, aExact)
  else
    Result := GetMaxCliqueDisconnected(aTimeOut, aExact);
end;

function TGSimpleGraph.GreedyMaxClique: TIntArray;
var
  vOrd, Idx2Ord: TIntArray;
  Stack: TIntSet;
  I, J, Cnt, MaxCnt: SizeInt;
  procedure CommGreedy;
  var
    Cand: TIntSet;
  begin
    I := vOrd[Pred(VertexCount)];
    {%H-}Stack.Push(I);
    Cand.AssignList(AdjLists[I]);
    while Cand.NonEmpty do
      begin
        MaxCnt := 0;
        J := NULL_INDEX;
        for I in Cand do
          begin
            Cnt := Succ(Cand.IntersectionCount(AdjLists[I]));
            if Cnt > MaxCnt then
              begin
                MaxCnt := Cnt;
                J := I;
              end
            else
              if (Cnt = MaxCnt) and (J >= 0) then
                if Idx2Ord[I] > Idx2Ord[J] then
                  J := I;
          end;
        Stack.Push(J);
        Cand.Intersect(AdjLists[J]);
      end;
  end;
  procedure BpGreedy;
  var
    m: TBoolMatrix;
    Cand: TBoolVector;
  begin
    m := CreateBoolMatrix;
    I := vOrd[Pred(VertexCount)];
    {%H-}Stack.Push(I);
    Cand := m[I];
    while Cand.NonEmpty do
      begin
        MaxCnt := 0;
        J := NULL_INDEX;
        for I in Cand do
          begin
            Cnt := Succ(Cand.IntersectionPop(m[I]));
            if Cnt > MaxCnt then
              begin
                MaxCnt := Cnt;
                J := I;
              end
            else
              if (Cnt = MaxCnt) and (J >= 0) then
                if Idx2Ord[I] > Idx2Ord[J] then
                  J := I;
          end;
        Stack.Push(J);
        Cand.Intersect(m[J]);
      end;
  end;
begin
  Result := nil;
  if IsEmpty then
    exit;
  vOrd := SortNodesByWidth(soAsc);
  Idx2Ord.Length := VertexCount;
  for I := 0 to Pred(VertexCount) do
    Idx2Ord[vOrd[I]] := I;
  if VertexCount > COMMON_BP_CUTOFF then
    CommGreedy
  else
    BpGreedy;
  Result := {%H-}Stack.ToArray;
end;

function TGSimpleGraph.IsMaxClique(const aTestClique: TIntArray): Boolean;
var
  TestClique, Remain: TBoolVector;
  I, J: SizeInt;
  AdjList: PAdjList;
  AdjFound: Boolean;
begin
  if IsEmpty then
    exit(aTestClique.IsEmpty);
  TestClique.Capacity := VertexCount;
  for I in aTestClique do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestClique.UncBits[I] then //contains duplicates -> is not set
        exit(False);
      TestClique.UncBits[I] := True;
    end;
  for I in aTestClique do
    begin
      AdjList := AdjLists[I];
      for J in aTestClique do
        if (I <> J) and not AdjList^.Contains(J) then //contains nonadjacent vertices -> is not clique
          exit(False);
    end;
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestClique);
  Finalize(TestClique);
  for I in Remain do
    begin
      AdjList := AdjLists[I];
      AdjFound := True;
      for J in aTestClique do
        if not AdjList^.Contains(J) then
          begin
            AdjFound := False;
            break;
          end;
      if AdjFound then // I can be added to clique -> clique is not maximal
        exit(False);
    end;
  Result := True;
end;

procedure TGSimpleGraph.ListAllMVC(aOnFound: TOnSetFound);
var
  Helper: TMvcHelper;
begin
  if VertexCount < 2 then
    exit;
  if aOnFound = nil then
    raise EGraphError.Create(SECallbackMissed);
  Helper.Init(Self, aOnFound);
  ListAllMIS(@Helper.SetFound);
end;

function TGSimpleGraph.FindMVC(out aExact: Boolean; aTimeOut: Integer): TIntArray;
var
  VertSet: TBoolVector;
  I: SizeInt;
begin
  aExact := True;
  if VertexCount < 2 then
    exit(nil);
  Result := FindMIS(aExact, aTimeOut);
  VertSet.InitRange(VertexCount);
  for I in Result do
    VertSet.UncBits[I] := False;
  Result := VertSet.ToArray;
end;

function TGSimpleGraph.GreedyMVC: TIntArray;
var
  VertSet: TBoolVector;
  I: SizeInt;
begin
  if VertexCount < 2 then
    exit(nil);
  Result := GreedyMIS;
  VertSet.InitRange(VertexCount);
  for I in Result do
    VertSet.UncBits[I] := False;
  Result := VertSet.ToArray;
end;

function TGSimpleGraph.IsMVC(const aTestMvc: TIntArray): Boolean;
var
  TestCover: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
  Covered: Boolean;
begin
  if IsEmpty then
    exit(aTestMvc.IsEmpty);
  TestCover.Capacity := VertexCount;
  for I in aTestMvc do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestCover.UncBits[I] then //contains duplicates -> is not set
        exit(False);
      TestCover.UncBits[I] := True;
    end;
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      if (p^.Key > I) and not(TestCover.UncBits[I] or TestCover.UncBits[p^.Key]) then
        exit(False);  //contains uncovered edge -> is not cover
  for I in aTestMvc do
    begin
      TestCover.UncBits[I] := False;
      Covered := True;
      for J := 0 to Pred(VertexCount) do
        for p in AdjLists[J]^ do
          if (p^.Key > J) and not (TestCover.UncBits[J] or TestCover.UncBits[p^.Key]) then
            begin
              Covered := False;
              break;
            end;
      if Covered then
        exit(False);  //I can be removed from cover -> cover is not minimal
      TestCover.UncBits[I] := True;
    end;
  Result := True;
end;

function TGSimpleGraph.VertexColoring(out aColors: TIntArray; out aExact: Boolean; aTimeOut: Integer): SizeInt;
begin
  //todo: planar graphs ?
  if ColorTrivial(Result, aColors) then
    aExact := True
  else
    if Connected then
      Result := ColorConnected(aTimeOut, aColors, aExact)
    else
      Result := ColorDisconnected(aTimeOut, aColors, aExact);
end;

function TGSimpleGraph.IsKColorable(aK: SizeInt; out aColors: TIntArray; aTimeOut: Integer): TTriLean;
var
  K: SizeInt;
begin
  if aK <= 0 then
    exit(tlFalse);
  if IsEmpty then
    exit(tlTrue);
  if aK >= VertexCount then
    begin
      aColors := TIntHelper.CreateRange(1, VertexCount);
      exit(tlTrue);
    end;
  if ColorTrivial(K, aColors) then
    if K <= aK then
      exit(tlTrue)
    else
      begin
        aColors := nil;
        exit(tlFalse);
      end;
  K := GreedyVertexColoringRlf(aColors);
  if K <= aK then
    exit(tlTrue);
  aColors := nil;
  if Connected then
    Result := ColorableConnected(aK, aTimeOut, aColors)
  else
    Result := ColorableDisconnected(aK, aTimeOut, aColors);
end;

function TGSimpleGraph.IsKColorCompletable(aK: SizeInt; var aColors: TIntArray; aTimeOut: Integer): TTriLean;
var
  Helper: TExactColor;
  I: SizeInt;
  p: PAdjItem;
begin
  if aK <= 0 then
    exit(tlFalse);
  if aColors.Length <> VertexCount then
    exit(tlFalse);
  for I in aColors do
    if (I < 0) or (I > aK) then
      exit(tlFalse);
  for I := 0 to Pred(VertexCount) do
    if aColors[I] > 0 then
      for p in AdjLists[I]^ do
        if (p^.Key > I) and (aColors[p^.Key] = aColors[I])  then
          exit(tlFalse);
  Result := Helper.Complete(Self, aK, aTimeOut, aColors);
end;

function TGSimpleGraph.GreedyVertexColoringRlf(out aColors: TIntArray): SizeInt;
var
  I: SizeInt;
begin
  if IsEmpty then
    begin
      aColors := nil;
      exit(1);
    end;
  if IsComplete then
    begin
      aColors.Length := VertexCount;
      for I := 0 to Pred(VertexCount) do
        aColors[I] := Succ(I);
      exit(VertexCount);
    end;
  Result := GreedyColorRlf(aColors);
end;

function TGSimpleGraph.GreedyVertexColoring(out aColors: TIntArray): SizeInt;
begin
  if not ColorTrivial(Result, aColors) then
    Result := GreedyColor(aColors);
end;

function TGSimpleGraph.IsProperVertexColoring(const aTestColors: TIntArray): Boolean;
var
  Color, I: SizeInt;
  p: PAdjItem;
begin
  if IsEmpty then
    exit(aTestColors = nil);
  if aTestColors.Length <> VertexCount then
    exit(False);
  for Color in aTestColors do
    if (Color < 1) or (Color > VertexCount) then
      exit(False);
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      if (p^.Key > I) and (aTestColors[I] = aTestColors[p^.Key]) then
        exit(False);
  Result := True;
end;

function TGSimpleGraph.FindHamiltonCycles(const aSource: TVertex; aCount: SizeInt; out aCycles: TIntArrayVector;
  aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonCyclesI(IndexOf(aSource), aCount, aCycles, aTimeOut);
end;

function TGSimpleGraph.FindHamiltonCyclesI(aSourceIdx, aCount: SizeInt; out aCycles: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonSearch;
  I: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  {%H-}aCycles.Clear;
  if not Connected or (VertexCount < 2) then
    exit(False);
  if VertexCount = 2 then
    begin
      if aSourceIdx = 0 then
        aCycles.Add([0, 1, 0])
      else
        aCycles.Add([1, 0, 1]);
      exit(True);
    end;
  for I := 0 to Pred(VertexCount) do
    if AdjLists[I]^.Count < 2 then
      exit(False);
  Result := Helper.FindCycles(Self, aSourceIdx, aCount, aTimeOut, @aCycles);
end;

function TGSimpleGraph.IsHamiltonCycle(const aTestCycle: TIntArray; aSourceIdx: SizeInt): Boolean;
var
  VertSet: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  if not Connected or (VertexCount < 2) then
    exit(False);
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

function TGSimpleGraph.FindHamiltonPaths(const aSource: TVertex; aCount: SizeInt; out aPaths: TIntArrayVector;
  aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonPathsI(IndexOf(aSource), aCount, aPaths, aTimeOut);
end;

function TGSimpleGraph.FindHamiltonPathsI(aSourceIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonSearch;
  I, LeafCount: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  {%H-}aPaths.Clear;
  if not Connected or (VertexCount < 2) then
    exit(False);
  LeafCount := 0;
  for I := 0 to Pred(VertexCount) do
    if AdjLists[I]^.Count < 2 then
      begin
        Inc(LeafCount);
        if LeafCount > 2 then
          exit(False);
      end;
  if (LeafCount = 2) and not (AdjLists[aSourceIdx]^.Count < 2) then
    exit(False);
  Result := Helper.FindPaths(Self, aSourceIdx, aCount, aTimeOut, @aPaths);
end;

function TGSimpleGraph.IsHamiltonPath(const aTestPath: TIntArray; aSourceIdx: SizeInt): Boolean;
var
  VertSet: TBoolVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  if not Connected or (VertexCount < 2) then
    exit(False);
  if aTestPath.Length <> VertexCount then
    exit(False);
  if aTestPath[0] <> aSourceIdx then
    exit(False);
  VertSet.Capacity := VertexCount;
  Next := aSourceIdx;
  VertSet.UncBits[aSourceIdx] := True;
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

{ TGSimpleObjGraph }

procedure TGSimpleObjGraph.ClearObjects;
var
  e: TEdge;
  I: SizeInt;
begin
  if OwnsEdges then
    for e in DistinctEdges do
      TObject(e.Data).Free;
  if OwnsVertices then
    for I := 0 to Pred(VertexCount) do
      TObject(FNodeList[I].Vertex).Free;
end;

procedure TGSimpleObjGraph.VertexReplaced(const v: TVertexClass);
begin
  if OwnsVertices then
    TObject(v).Free;
end;

procedure TGSimpleObjGraph.DoRemoveVertex(aIndex: SizeInt);
var
  p: PAdjItem;
begin
  if OwnsEdges then
    for p in AdjLists[aIndex]^ do
      TObject(p^.Data).Free;
  if OwnsVertices then
    TObject(FNodeList[aIndex].Vertex).Free;
  inherited DoRemoveVertex(aIndex);
end;

function TGSimpleObjGraph.DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
var
  e: TEdgeClass;
begin
  if OwnsEdges then
    begin
      Result := FNodeList[aSrc].AdjList.Remove(aDst, e);
      if Result then
        begin
          FNodeList[aDst].AdjList.Remove(aSrc);
          Dec(FEdgeCount);
          FConnectedValid := False;
          TObject(e).Free;
        end;
    end
  else
    Result := inherited DoRemoveEdge(aSrc, aDst)
end;

function TGSimpleObjGraph.DoSetEdgeData(aSrc, aDst: SizeInt; const aValue: TEdgeClass): Boolean;
var
  p: PAdjItem;
begin
  p := AdjLists[aSrc]^.Find(aDst);
  Result := p <> nil;
  if Result then
    begin
      if OwnsEdges then
        TObject(p^.Data).Free;
      p^.Data := aValue;
      AdjLists[aDst]^.Find(aSrc)^.Data := aValue;
    end;
end;

constructor TGSimpleObjGraph.Create(aOwns: TObjOwnership);
begin
  inherited Create;
  OwnsVertices := ooOwnsVertices in aOwns;
  OwnsEdges := ooOwnsEdges in aOwns;
end;

destructor TGSimpleObjGraph.Destroy;
begin
  ClearObjects;
  inherited;
end;

procedure TGSimpleObjGraph.Clear;
begin
  ClearObjects;
  inherited;
end;

{ TGChart }

procedure TGChart.ReadData(aStream: TStream; out aValue: TDummy);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
end;

procedure TGChart.WriteData(aStream: TStream; const aValue: TDummy);
begin
  aStream.WriteBuffer(aValue, SizeOf(aValue));
end;

function TGChart.SeparateGraph(const aVertex: TVertex): TGChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGChart.SeparateGraphI(aIndex: SizeInt): TGChart;
begin
  Result := TGChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGChart.InducedSubgraph(const aVertexList: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGChart.SubgraphFromTree(const aTree: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TGChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGChart.CreatePermutation(const aMap: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignPermutation(Self, aMap);
end;

function TGChart.Clone: TGChart;
begin
  Result := TGChart.Create;
  Result.AssignGraph(Self);
end;

procedure TGChart.SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToStream(aStream, aOnWriteVertex, @WriteData);
end;

procedure TGChart.LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromStream(aStream, aOnReadVertex, @ReadData);
end;

procedure TGChart.SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToFile(aFileName, aOnWriteVertex, @WriteData);
end;

procedure TGChart.LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromFile(aFileName, aOnReadVertex, @ReadData);
end;

procedure TGChart.SetUnionOf(aChart: TGChart);
var
  v: TVertex;
  e: TEdge;
begin
  for v in aChart.Vertices do
    AddVertex(v);
  for e in aChart.DistinctEdges do
    AddEdge(aChart[e.Source], aChart[e.Destination]);
end;

procedure TGChart.SetIntersectionOf(aChart: TGChart);
var
  Tmp: TGChart;
  s, d: TVertex;
  e: TEdge;
begin
  Tmp := TGChart.Create;
  try
    Tmp.Title := Title;
    Tmp.Description := Description;
    for s in Vertices do
      if aChart.ContainsVertex(s) then
        Tmp.AddVertex(s);
    for e in DistinctEdges do
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

{ TIntChart }

procedure TIntChart.WriteVertex(aStream: TStream; const aValue: Integer);
begin
  aStream.WriteBuffer(NtoLE(aValue), SizeOf(aValue));
end;

procedure TIntChart.ReadVertex(aStream: TStream; out aValue: Integer);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue := LEtoN(aValue);
end;

procedure TIntChart.LoadDIMACSAscii(const aFileName: string);
var
  Ref: specialize TGAutoRef<TTextFileReader>;
  Reader: TTextFileReader;
  Line, ParseLine: string;
  Src, Dst: SizeInt;
  Symb: AnsiChar;
begin
  Reader := {%H-}Ref;
  if not Reader.Open(aFileName) then
    raise EGraphError.CreateFmt(SEUnableOpenFileFmt3, [aFileName, Reader.ExceptionClass, Reader.ExceptionMessage]);
  Clear;
  for Line in Reader do
    begin
      ParseLine := Trim(Line);
      if ParseLine <> '' then
        case ParseLine[1] of
          'c':
            if Description <> '' then
              Description := Description + SLineBreak +
                            System.Copy(ParseLine, 3, System.Length(ParseLine))
            else
              Description := System.Copy(ParseLine, 3, System.Length(ParseLine));
          'e':
            begin
              ReadStr(ParseLine, Symb, Src, Dst);
              AddEdge(Src, Dst);
            end;
      end;
    end;
end;

function TIntChart.SeparateGraph(aVertex: Integer): TIntChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TIntChart.SeparateGraphI(aIndex: SizeInt): TIntChart;
begin
  Result := TIntChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TIntChart.InducedSubgraph(const aVertexList: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TIntChart.SubgraphFromTree(const aTree: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TIntChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TIntChart.CreatePermutation(const aMap: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignPermutation(Self, aMap);
end;

function TIntChart.Clone: TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignGraph(Self);
end;

procedure TIntChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TIntChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TIntChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TIntChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

function TIntChart.AddVertexRange(aFrom, aTo: Integer): Integer;
var
  I: Integer;
begin
  Result := VertexCount;
  for I := aFrom to aTo do
    AddVertex(I);
  Result := VertexCount - Result;
end;

function TIntChart.AddEdges(const aVertexList: array of Integer): Integer;
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

{ TGraphDotWriter }

procedure TGraphDotWriter.WriteEdges(aGraph: TGraph; aList: TStrings);
var
  e: TGraph.TEdge;
  s: string;
begin
  for e in TSimpleGraph(aGraph).DistinctEdges do
    begin
      if Assigned(OnWriteEdge) then
        s := OnWriteEdge(aGraph, e)
      else
        s := DefaultWriteEdge(aGraph, e);
      aList.Add(s);
    end;
end;

constructor TGraphDotWriter.Create;
begin
  FGraphMark := 'graph ';
  FEdgeMark := '--';
end;

{ TIntChartDotWriter }

function TIntChartDotWriter.DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string;
begin
  Result := IntToStr(aGraph[aEdge.Source]) + FEdgeMark + IntToStr(aGraph[aEdge.Destination]) + ';';
end;

{ TStrChart }

procedure TStrChart.WriteVertex(aStream: TStream; const aValue: string);
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

procedure TStrChart.ReadVertex(aStream: TStream; out aValue: string);
var
  Len: SmallInt;
begin
  aStream.ReadBuffer(Len{%H-}, SizeOf(Len));
  System.SetLength(aValue, Len);
  aStream.ReadBuffer(Pointer(aValue)^, Len);
end;

function TStrChart.SeparateGraph(const aVertex: string): TStrChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TStrChart.SeparateGraphI(aIndex: SizeInt): TStrChart;
begin
  Result := TStrChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TStrChart.InducedSubgraph(const aVertexList: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TStrChart.SubgraphFromTree(const aTree: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TStrChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TStrChart.CreatePermutation(const aMap: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignPermutation(Self, aMap);
end;

function TStrChart.Clone: TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignGraph(Self);
end;

procedure TStrChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TStrChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TStrChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TStrChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

function TStrChart.AddEdges(const aVertexList: array of string): Integer;
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

{ TStrChartDotWriter }

function TStrChartDotWriter.DefaultWriteEdge(aGraph: TGraph; const aEdge: TGraph.TEdge): string;
begin
  Result := '"' + aGraph[aEdge.Source] + '"' + FEdgeMark + '"' + aGraph[aEdge.Destination] + '";';
end;

{ TGWeightedGraph }

function TGWeightedGraph.CreateEdgeArray: TEdgeArray;
var
  I, J: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(Result, EdgeCount);
  J := 0;
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      if p^.Destination > I then
        begin
          Result[J] := TWeightEdge.Create(I, p^.Destination, p^.Data.Weight);
          Inc(J);
        end;
end;

class function TGWeightedGraph.InfWeight: TWeight;
begin
  Result := TWeight.INF_VALUE;
end;

class function TGWeightedGraph.NegInfWeight: TWeight;
begin
  Result := TWeight.NEGINF_VALUE;
end;

class function TGWeightedGraph.TotalWeight(const aEdges: TEdgeArray): TWeight;
var
  e: TWeightEdge;
begin
  Result := TWeight(0);
  for e in aEdges do
    Result += e.Weight;
end;

class function TGWeightedGraph.EdgeArray2IntEdgeArray(const a: TEdgeArray): TIntEdgeArray;
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

function TGWeightedGraph.ContainsNegWeightEdge: Boolean;
var
  e: TEdge;
begin
  for e in DistinctEdges do
    if e.Data.Weight < TWeight(0) then
      exit(True);
  Result := False;
end;

function TGWeightedGraph.ContainsNegCycle(const aRoot: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsNegCycleI(IndexOf(aRoot), aCycle);
end;

function TGWeightedGraph.ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
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

function TGWeightedGraph.SeparateGraph(const aVertex: TVertex): TGWeightedGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGWeightedGraph.SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGWeightedGraph.InducedSubgraph(const aVertexList: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGWeightedGraph.SubgraphFromTree(const aTree: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGWeightedGraph.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGWeightedGraph.Clone: TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignGraph(Self);
end;

function TGWeightedGraph.MinPathsMap(const aSrc: TVertex): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc));
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt): TWeightArray;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.DijkstraSssp(Self, aSrc)
  else
    Result := [TWeight(0)];
end;

function TGWeightedGraph.MinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
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

function TGWeightedGraph.FindMinPathsMap(const aSrc: TVertex; out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
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

function TGWeightedGraph.FindMinPathsMap(const aSrc: TVertex; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aPathTree, aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  if VertexCount > 1 then
    Result := TWeightHelper.BfmtSssp(Self, aSrc, aPathTree, aWeights)
  else
    begin
      aPathTree := [NULL_INDEX];
      aWeights := [TWeight(0)];
      Result := True;
    end;
end;

function TGWeightedGraph.MinPath(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
begin
  Result := MinPathI(IndexOf(aSrc), IndexOf(aDst), aWeight);
end;

function TGWeightedGraph.MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.MinPathBiDir(const aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
begin
  Result := MinPathBiDirI(IndexOf(aSrc), IndexOf(aDst), aWeight);
end;

function TGWeightedGraph.MinPathBiDirI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  Result := TWeightHelper.BiDijkstraPath(Self, Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.FindMinPath(const aSrc, aDst: TVertex; out aPath: TIntArray;
  out aWeight: TWeight): Boolean;
begin
  Result := FindMinPathI(IndexOf(aSrc), IndexOf(aDst), aPath, aWeight);
end;

function TGWeightedGraph.FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      aPath := nil;
      exit(True);
    end;
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    begin
      aWeight := InfWeight;
      aPath := nil;
      exit(False);
    end;
  Result := TWeightHelper.BfmtPath(Self, aSrc, aDst, aPath, aWeight);
end;

function TGWeightedGraph.MinPathAStar(const aSrc, aDst: TVertex; out aWeight: TWeight;
  aEst: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aSrc), aWeight, aEst);
end;

function TGWeightedGraph.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  if aEst <> nil then
    Result := TWeightHelper.AStar(Self, aSrc, aDst, aWeight, aEst)
  else
    Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.MinPathNBAStar(const aSrc, aDst: TVertex; out aWeight: TWeight;
  aEst: TEstimate): TIntArray;
begin
  Result := MinPathNBAStarI(IndexOf(aSrc), IndexOf(aSrc), aWeight, aEst);
end;

function TGWeightedGraph.MinPathNBAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    begin
      aWeight := TWeight(0);
      exit(nil);
    end;
  if ConnectedValid and (SeparateTag(aSrc) <> SeparateTag(aDst)) then
    begin
      aWeight := InfWeight;
      exit(nil);
    end;
  if aEst <> nil then
    Result := TWeightHelper.NBAStar(Self, Self, aSrc, aDst, aWeight, aEst)
  else
    Result := TWeightHelper.BiDijkstraPath(Self, Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.CreateWeightsMatrix: TWeightMatrix;
begin
  Result := TWeightHelper.CreateWeightsMatrix(Self);
end;

function TGWeightedGraph.FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
begin
  if VertexCount > 1 then
    if Density <= DENSE_CUTOFF then
      Result := TWeightHelper.BfmtApsp(Self, False, aPaths)
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

function TGWeightedGraph.ExtractMinPath(const aSrc, aDst: TVertex; const aPaths: TApspMatrix): TIntArray;
begin
  Result := ExtractMinPathI(IndexOf(aSrc), IndexOf(aDst), aPaths);
end;

function TGWeightedGraph.ExtractMinPathI(aSrc, aDst: SizeInt; const aPaths: TApspMatrix): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    Result := nil
  else
    Result := TWeightHelper.ExtractMinPath(aSrc, aDst, aPaths);
end;

function TGWeightedGraph.FindEccentricity(const aVertex: TVertex; out aValue: TWeight): Boolean;
begin
  Result := FindEccentricityI(IndexOf(aVertex), aValue);
end;

function TGWeightedGraph.FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
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

function TGWeightedGraph.FindWeightedMetrics(out aRadius, aDiameter: TWeight): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Weights: TWeightArray;
  I, J: SizeInt;
  Ecc, w: TWeight;
begin
  aRadius := TWeight.INF_VALUE;
  aDiameter := TWeight.INF_VALUE;
  if not Connected then
    exit(False);
  Result := TWeightHelper.BfmtReweight(Self, Weights) < 0;
  if not Result then
    exit;
  Weights := nil;
  aDiameter := 0;
  Bfmt := TWeightHelper.TBfmt.Create(Self, False);
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

function TGWeightedGraph.FindWeightedCenter(out aCenter: TIntArray): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Eccs: TWeightArray;
  I, J: SizeInt;
  Radius, Ecc, w: TWeight;
begin
  aCenter := nil;
  if not Connected then
    exit(False);
  Result := TWeightHelper.BfmtReweight(Self, Eccs) < 0;
  if not Result then
    exit;
  Bfmt := TWeightHelper.TBfmt.Create(Self, False);
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

function TGWeightedGraph.MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntEdgeArray;
var
  e: TWeightEdge;
  LocEdges: TEdgeArray;
  Dsu: TDisjointSetUnion;
  I: SizeInt = 0;
begin
  LocEdges := CreateEdgeArray;
  TEdgeHelper.Sort(LocEdges);
  System.SetLength(Result, VertexCount);
  Dsu.Size := VertexCount;
  aTotalWeight := TWeight(0);
  for e in LocEdges do
    if Dsu.Join(e.Source, e.Destination)  then
      begin
        Result[I] := TIntEdge.Create(e.Source, e.Destination);
        aTotalWeight += e.Weight;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

function TGWeightedGraph.MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
var
  Queue: specialize TGPairHeapMin<TWeightItem>;
  Reached, InQueue: TBoolVector;
  I, Curr: SizeInt;
  Item: TWeightItem;
  p: PAdjItem;
begin
  Result := CreateIntArray;
  Queue := specialize TGPairHeapMin<TWeightItem>.Create(VertexCount);
  Reached.Capacity := VertexCount;
  InQueue.Capacity := VertexCount;
  aTotalWeight := 0;
  for I := 0 to Pred(VertexCount) do
    if not Reached.UncBits[I] then
      begin
        Item := TWeightItem.Create(I, 0);
        repeat
          Curr := Item.Index;
          aTotalWeight += Item.Weight;
          Reached.UncBits[Curr] := True;
          for p in AdjLists[Curr]^ do
            if not Reached.UncBits[p^.Key] then
              if not InQueue.UncBits[p^.Key] then
                begin
                  Queue.Enqueue(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                  Result[p^.Key] := Curr;
                  InQueue.UncBits[p^.Key] := True;
                end
              else
                if p^.Data.Weight < Queue.GetItemPtr(p^.Key)^.Weight then
                  begin
                    Queue.Update(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                    Result[p^.Key] := Curr;
                  end;
        until not Queue.TryDequeue(Item);
      end;
end;

{ TPointsChart }

procedure TPointsChart.OnAddEdge(const aSrc, aDst: TPoint; var aData: TRealWeight);
begin
  aData.Weight := aSrc.Distance(aDst);
end;

procedure TPointsChart.WritePoint(aStream: TStream; const aValue: TPoint);
var
  p: TPoint;
begin
  p.X := NtoLE(aValue.X);
  p.Y := NtoLE(aValue.Y);
  aStream.WriteBuffer(p, SizeOf(p));
end;

procedure TPointsChart.ReadPoint(aStream: TStream; out aValue: TPoint);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue.X := LEtoN(aValue.X);
  aValue.Y := LEtoN(aValue.Y);
end;

procedure TPointsChart.WriteData(aStream: TStream; const aValue: TRealWeight);
var
  Buf: Double;
begin
  Buf := aValue.Weight;
  aStream.WriteBuffer(Buf, SizeOf(Buf));
end;

procedure TPointsChart.ReadData(aStream: TStream; out aValue: TRealWeight);
var
  Buf: Double;
begin
  aStream.ReadBuffer(Buf{%H-}, SizeOf(Buf));
  aValue.Weight := Buf;
end;

class function TPointsChart.Distance(const aSrc, aDst: TPoint): ValReal;
begin
  Result := aSrc.Distance(aDst);
end;

function TPointsChart.AddEdge(const aSrc, aDst: TPoint): Boolean;
begin
  Result := inherited AddEdge(aSrc, aDst, TRealWeight.Create(aSrc.Distance(aDst)));
end;

function TPointsChart.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := inherited AddEdgeI(aSrc, aDst, TRealWeight.Create(Items[aSrc].Distance(Items[aDst])));
end;

function TPointsChart.EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited EnsureConnected(aOnAddEdge)
  else
    Result := inherited EnsureConnected(@OnAddEdge);
end;

function TPointsChart.RemoveCutPoints(const aRoot: TPoint; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited RemoveCutVertices(aRoot, aOnAddEdge)
  else
    Result := inherited RemoveCutVertices(aRoot, @OnAddEdge);
end;

function TPointsChart.RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited RemoveCutVerticesI(aRoot, aOnAddEdge)
  else
    Result := inherited RemoveCutVerticesI(aRoot, @OnAddEdge);
end;

function TPointsChart.EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited EnsureBiconnected(aOnAddEdge)
  else
    Result := inherited EnsureBiconnected(@OnAddEdge);
end;

function TPointsChart.SeparateGraph(aVertex: TPoint): TPointsChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TPointsChart.SeparateGraphI(aIndex: SizeInt): TPointsChart;
begin
  Result := TPointsChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TPointsChart.InducedSubgraph(const aVertexList: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TPointsChart.SubgraphFromTree(const aTree: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TPointsChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TPointsChart.Clone: TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignGraph(Self);
end;

procedure TPointsChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WritePoint, @WriteData);
end;

procedure TPointsChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadPoint, @ReadData);
end;

procedure TPointsChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WritePoint, @WriteData);
end;

procedure TPointsChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadPoint, @ReadData);
end;

function TPointsChart.MinPathAStar(const aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aDst), aWeight, aHeur);
end;

function TPointsChart.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  if aHeur = nil then
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, @Distance)
  else
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, aHeur);
end;

function TPointsChart.MinPathNBAStar(const aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  Result := MinPathNBAStarI(IndexOf(aSrc), IndexOf(aDst), aWeight, aHeur);
end;

function TPointsChart.MinPathNBAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  if aHeur = nil then
    Result := inherited MinPathNBAStarI(aSrc, aDst, aWeight, @Distance)
  else
    Result := inherited MinPathNBAStarI(aSrc, aDst, aWeight, aHeur);
end;

{$I GlobMinCut.inc}

{ TGInt64Net }

function TGInt64Net.GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
var
  d: TEdgeData;
begin
  aCutSet := Default(TIntSet);
  if not Connected or (VertexCount < 2) then
    begin
      aCutWeight := 0;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := Default(TEdgeData);
      GetEdgeDataI(0, 1, d);
      aCutWeight := d.Weight;
      aCutSet.Add(0);
      exit(True);
    end;
  Result := False;
end;

function TGInt64Net.GetTrivialMinCut(out aCut: TWeight): Boolean;
var
  d: TEdgeData;
begin
  if not Connected or (VertexCount < 2) then
    begin
      aCut := 0;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := Default(TEdgeData);
      GetEdgeDataI(0, 1, d);
      aCut := d.Weight;
      exit(True);
    end;
  Result := False;
end;

function TGInt64Net.StoerWagner(out aCut: TIntSet): TWeight;
var
  Queue: specialize TGPairHeapMax<TWeightItem>;
  g: array of TSWAdjList;
  Cuts: array of TIntSet;
  vRemains, vInQueue: TBoolVector;
  Phase, Prev, Last, I: SizeInt;
  p: PAdjItem;
  pItem: ^TWeightItem;
  NextItem: TWeightItem;
begin
  //initialize
  System.SetLength(g, VertexCount);
  for I := 0 to Pred(VertexCount) do
    begin
      g[I].EnsureCapacity(DegreeI(I));
      for p in AdjLists[I]^ do
        g[I].Add(TWeightItem.Create(p^.Destination, p^.Data.Weight));
    end;
  System.SetLength(Cuts, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Cuts[I].Add(I);
  Queue := specialize TGPairHeapMax<TWeightItem>.Create(VertexCount);
  vRemains.InitRange(VertexCount);
  vInQueue.Capacity := VertexCount;
  Result := MAX_WEIGHT;
  //n-1 phases
  for Phase := 1 to Pred(VertexCount) do
    begin
      vInQueue.Join(vRemains);
      for I in vRemains do
        Queue.Enqueue(I, TWeightItem.Create(I, 0));
      while Queue.Count > 1 do
        begin
          Prev := Queue.Dequeue.Index;
          vInQueue.UncBits[Prev] := False;
          for pItem in g[Prev] do
            if vInQueue.UncBits[pItem^.Index] then
              begin
                NextItem := Queue.GetItem(pItem^.Index);
                NextItem.Weight += pItem^.Weight;
                Queue.Update(pItem^.Index, NextItem);
              end;
        end;
      NextItem := Queue.Dequeue;
      Last := NextItem.Index;
      vInQueue.UncBits[NextItem.Index] := False;
      if Result > NextItem.Weight then
        begin
          Result := NextItem.Weight;
          aCut.Assign(Cuts[Last]);
        end;
      while Cuts[Last].TryPop(I) do
        Cuts[Prev].Push(I);
      Finalize(Cuts[Last]);
      vRemains.UncBits[Last] := False;
      //merge last two vertices, remain Prev
      g[Prev].Remove(Last);
      g[Last].Remove(Prev);
      g[Prev].AddAll(g[Last]);
      for pItem in g[Last] do
        begin
          I := pItem^.Index;
          NextItem := pItem^;
          g[I].Remove(Last);
          NextItem.Index := Prev;
          g[I].Add(NextItem);
        end;
      Finalize(g[Last]);
    end;
end;

function TGInt64Net.SeparateGraph(const aVertex: TVertex): TGInt64Net;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGInt64Net.SeparateGraphI(aIndex: SizeInt): TGInt64Net;
begin
  Result := TGInt64Net.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGInt64Net.InducedSubgraph(const aVertexList: TIntArray): TGInt64Net;
begin
  Result := TGInt64Net.Create;
  Result.AssignVertexList(Self, aVertexList);
end;

function TGInt64Net.SubgraphFromTree(const aTree: TIntArray): TGInt64Net;
begin
  Result := TGInt64Net.Create;
  Result.AssignTree(Self, aTree);
end;

function TGInt64Net.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGInt64Net;
begin
  Result := TGInt64Net.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGInt64Net.Clone: TGInt64Net;
begin
  Result := TGInt64Net.Create;
  Result.AssignGraph(Self);
end;

function TGInt64Net.FindMinWeightBipMatch(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  aMatch := nil;
  Result := IsBipartite(w, g);
  if Result then
    aMatch := TWeightHelper.MinBipMatch(Self, w, g);
end;

function TGInt64Net.FindMaxWeightBipMatch(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  aMatch := nil;
  Result := IsBipartite(w, g);
  if Result then
    aMatch := TWeightHelper.MaxBipMatch(Self, w, g);
end;

function TGInt64Net.MinWeightCutSW(out aCut: TCut; out aCutWeight: TWeight): TGlobalNetState;
var
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
  e: TEdge;
begin
  aCutWeight := 0;
  aCut.A := nil;
  aCut.B := nil;
  if VertexCount < 2 then
    exit(gnsTrivial);
  if not Connected then
    exit(gnsDisconnected);
  for e in DistinctEdges do
    if e.Data.Weight < 0 then
      exit(gnsNegEdgeCapacity);
  aCutWeight := StoerWagner(Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B.UncBits[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
  Result := gnsOk;
end;

function TGInt64Net.MinWeightCutNI(out aCutWeight: TWeight): TGlobalNetState;
var
  Helper: TNIMinCutHelper;
  e: TEdge;
begin
  aCutWeight := 0;
  if VertexCount < 2 then
    exit(gnsTrivial);
  if not Connected then
    exit(gnsDisconnected);
  for e in DistinctEdges do
    if e.Data.Weight < 0 then
      exit(gnsNegEdgeCapacity);
  aCutWeight := Helper.GetMinCut(Self);
  Result := gnsOk;
end;

function TGInt64Net.MinWeightCutNI(out aCut: TCut; out aCutWeight: TWeight): TGlobalNetState;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Total: TBoolVector;
  I: SizeInt;
  e: TEdge;
begin
  aCutWeight := 0;
  aCut.A := nil;
  aCut.B := nil;
  if VertexCount < 2 then
    exit(gnsTrivial);
  if not Connected then
    exit(gnsDisconnected);
  for e in DistinctEdges do
    if e.Data.Weight < 0 then
      exit(gnsNegEdgeCapacity);
  aCutWeight := Helper.GetMinCut(Self, Cut);
  Total.InitRange(VertexCount);
  for I in Cut do
    Total.UncBits[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := Total.ToArray;
  Result := gnsOk;
end;

function TGInt64Net.MinWeightCutNI(out aCut: TCut; out aCrossEdges: TEdgeArray): TGlobalNetState;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Left, Right: TBoolVector;
  I, J: SizeInt;
  e: TEdge;
  p: PAdjItem;
  d: TEdgeData;
begin
  aCrossEdges := nil;
  aCut.A := nil;
  aCut.B := nil;
  if VertexCount < 2 then
    exit(gnsTrivial);
  if not Connected then
    exit(gnsDisconnected);
  for e in DistinctEdges do
    if e.Data.Weight < 0 then
      exit(gnsNegEdgeCapacity);
  Helper.GetMinCut(Self, Cut);
  if Cut.Count <= VertexCount shr 1 then
    begin
      Left.Capacity := VertexCount;
      Right.InitRange(VertexCount);
      for I in Cut do
        begin
          Left.UncBits[I] := True;
          Right.UncBits[I] := False;
        end;
    end
  else
    begin
      Right.Capacity := VertexCount;
      Left.InitRange(VertexCount);
      for I in Cut do
        begin
          Right.UncBits[I] := True;
          Left.UncBits[I] := False;
        end;
    end;
  aCut.A := Left.ToArray;
  aCut.B := Right.ToArray;
  System.SetLength(aCrossEdges, Left.PopCount);
  J := 0;
  d := Default(TEdgeData);
  for I in Left do
    for p in AdjLists[I]^ do
      if Right.UncBits[p^.Destination] then
        begin
          GetEdgeDataI(I, p^.Destination, d);
          if I < p^.Destination then
            aCrossEdges[J] := TWeightEdge.Create(I, p^.Destination, d.Weight)
          else
            aCrossEdges[J] := TWeightEdge.Create(p^.Destination, I, d.Weight);
          Inc(J);
        end;
  System.SetLength(aCrossEdges, J);
  Result := gnsOk;
end;

end.

