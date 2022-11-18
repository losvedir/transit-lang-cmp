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
  TWeightArcSpec = specialize TGLiteHashMapLP<TIntEdge, TWeight, TIntEdge>;
  TWeightArcMap  = TWeightArcSpec.TMap;

  { THPrHelper: an implementation of the high-level push-relabel method;
    B.V. Cherkassky, A.V. Goldberg: On Implementing Push-Relabel Method for the Maximum Flow Problem. }
  THPrHelper = record
  strict private
  type
    PNode = ^TNode;
    PArc  = ^TArc;

    TArc = record
      Target: PNode;       // pointer to target node
      Reverse: PArc;       // pointer to opposite arc
      ResCap: TWeight;     // residual capacity
      IsForward: Boolean;
      constructor Create(aTarget: PNode; aReverse: PArc; aCap: TWeight);
      constructor CreateReverse(aTarget: PNode; aReverse: PArc);
      function  IsSaturated: Boolean; inline;
      function  IsResidual: Boolean; inline;
      procedure Push(aFlow: TWeight); inline;
    end;

    TNode = record
    private
      function  GetColor: TVertexColor; inline;
      procedure SetColor(aValue: TVertexColor); inline;
    public
      FirstArc,            // pointer to first incident arc
      CurrentArc: PArc;    // pointer to current incident arc
      LevelNext,           // next node in level list
      LevelPrev: PNode;    // previous node in level list
      Excess: TWeight;     // excess at the node
      Distance: SizeInt;   // distance from the sink
      procedure Reset; inline;
      property  OrderNext: PNode read LevelNext write LevelNext;  // for dfs
      property  Parent: PNode read LevelPrev write LevelPrev;     // for dfs
      property  Color: TVertexColor read GetColor write SetColor; // for dfs
    end;


    TLevel = record
      TopActive,          // head of singly linked list of the nodes with positive excess
      TopIdle: PNode;     // head of doubly linked list of the nodes with zero excess
      function  IsEmpty: Boolean; inline;
      procedure AddActive(aNode: PNode); inline;
      procedure AddIdle(aNode: PNode);
      procedure Activate(aNode: PNode); inline;
      procedure RemoveIdle(aNode: PNode);
      procedure Clear(aLabel: SizeInt);
    end;

  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FLevels: array of TLevel;
    FCaps: TWeightArray;
    FQueue: array of PNode;
    FSource,
    FSink: PNode;
    FNodeCount,
    FMaxLevel,                // max level
    FMaxActiveLevel,          // max level with excessed node
    FMinActiveLevel: SizeInt; // min level with excessed node
    procedure CreateResidualNet(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt);
    procedure CreateResidualNetCap(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight);
    procedure ClearLabels;
    procedure GlobalRelabel;
    procedure RemoveGap(aLayer: SizeInt);
    function  Push(aNode: PNode): Boolean;
    procedure Relabel(aNode: PNode);
    procedure Execute;
    function  CreateArcFlows: TEdgeArray;
    function  RecoverFlow: TEdgeArray;
  public
    function  GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt): TWeight;
    function  GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; out a: TEdgeArray): TWeight;
    function  GetMinCut(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; out s: TIntArray): TWeight;
    function  GetFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out a: TEdgeArray): TWeight;
    function  GetFlowMap(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out m: TWeightArcMap): TWeight;
  end;

  { TDinitzHelper: implementation of capacity scaling Dinitz's maxflow algorithm }
  TDinitzHelper = record
  strict private
  type
    PNode = ^TNode;
    PArc  = ^TArc;

    TArc = record
      Target: PNode;       // pointer to target node
      Reverse: PArc;       // pointer to opposite arc
      ResCap: TWeight;     // residual capacity
      IsForward: Boolean;
      constructor Create(aTarget: PNode; aReverse: PArc; aCap: TWeight);
      constructor CreateReverse(aTarget: PNode; aReverse: PArc);
      procedure Push(aFlow: TWeight); inline;
    end;

    TNode = record
    private
      FirstArc,            // pointer to first incident arc
      CurrentArc: PArc;    // pointer to current incident arc
      Distance: SizeInt;   // distance from the source
      procedure Reset; inline;
    end;

  const
    MIN_SCALE = 6;

  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FQueue: array of PNode;
    FSource,
    FSink: PNode;
    FEpsilon: TWeight;
    FScaleFactor,
    FNodeCount: SizeInt;
    procedure CreateResidualNet(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt);
    procedure ClearLabels;
    function  BuildLevelGraph: Boolean;
    function  FindBlockingFlow(aRoot: PNode; aFlow: TWeight): TWeight;
    function  Execute: TWeight;
    function  Execute(aReqFlow: TWeight): TWeight;
    function  CreateArcFlows(aGraph: TGDirectInt64Net): TEdgeArray;
  public
    function  GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt): TWeight;
    function  GetMaxFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; out a: TEdgeArray): TWeight;
    function  GetMinCut(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; out s: TIntArray): TWeight;
    function  GetFlow(aGraph: TGDirectInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out a: TEdgeArray): TWeight;
  end;


