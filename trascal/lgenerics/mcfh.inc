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
  { TSspMcfHelper: Busacker-Gowen's successive shortest path minimum-cost flow algorithm with
    potentials; Syslo, Deo, Kowalik "Discrete Optimization Algorithms: With Pascal Programs" }
  TSspMcfHelper = record
  strict private
  type
    PNode  = ^TNode;
    PArc   = ^TArc;

    TArc = record
      Target: PNode;       // pointer to target node
      Reverse: PArc;       // pointer to opposite arc
      ResCap: TWeight;     // residual capacity
      Cost: TCost;
      IsForward: Boolean;
      constructor Create(aTarget: PNode; aReverse: PArc; aCap: TWeight; aCost: TCost);
      constructor CreateReverse(aTarget: PNode; aReverse: PArc; aCost: TCost);
      procedure Push(aFlow: TWeight); inline;
    end;

    TNode = record
    private
      FirstArc,            // pointer to first incident arc
      PathArc: PArc;       // pointer to incoming path arc
      Parent: PNode;
      Price: TCost;
      PathMinCap: TWeight; // munimum capacity on path
    end;
    THeap  = specialize TGPairHeapMin<TCostItem>;

  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FQueue: THeap;
    FInQueue: TBoolVector;
    FReached: TBoolVector;
    FSource,
    FSink: PNode;
    FGraph: TGCostedInt64Net;
    FRequestFlow: TWeight;
    FNodeCount: SizeInt;
    procedure CreateResidualNet(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight);
    procedure SearchInit;
    function  SetNodePrices: Boolean;
    function  FindAugmentPath: Boolean;
    function  PushFlow(aRestFlow: TWeight): TWeight;
    function  Execute: TWeight;
    function  GetTotalCost: TCost;
    function  CreateArcFlows(out aTotalCost: TCost): TEdgeArray;
  public
    function  GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out aTotalCost: TCost): TWeight;
    function  GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out aTotalCost: TCost; out a: TEdgeArray): TWeight;
  end;

  { TCsMcfHelper: basic implementation of cost scaling mincost flow algorithm;
      A.V.Goldberg and M.Kharitonov. "On Implementing Scaling Push-Relabel Algorithms for the
      Minimum-Cost Flow Problem";
    todo: more crucial heurictics }
  TCsMcfHelper = record
  strict private
  type
    PNode  = ^TNode;
    PArc   = ^TArc;

    TArc = record
      Target: PNode;       // pointer to target node
      Reverse: PArc;       // pointer to opposite arc
      ResCap: TWeight;     // residual capacity
      Cost: TCost;
      IsForward: Boolean;
      constructor Create(aTarget: PNode; aReverse: PArc; aCap: TWeight; aCost: TCost);
      constructor CreateReverse(aTarget: PNode; aReverse: PArc; aCost: TCost);
      procedure Push(aFlow: TWeight); inline;
      procedure PushAll; inline;
    end;

    TNode = record
    private
      FirstArc,            // pointer to first incident arc
      CurrArc: PArc;       // pointer to current incident arc
      Price: TCost;
      Excess: TWeight;     // excess at the node
      procedure Reset; inline;
    end;
    TQueue = specialize TGLiteQueue<PNode>;

  const
    ALPHA: TCost = TCost(8);

  var
    FNodes: array of TNode;
    FArcs: array of TArc;
    FQueue: TQueue;
    FInQueue: TBoolVector;
    FGraph: TGCostedInt64Net;
    FSource,
    FSink: PNode;
    FRequestFlow,
    FResultFlow: TWeight;
    FScaleFactor,
    FEpsilon: TCost;
    FNodeCount: SizeInt;
    procedure CreateResidualNet(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight);
    function  IndexOf(aNode: PNode): SizeInt; inline;
    function  PriceUpdate: Boolean;
    function  FindRequiredFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; out m: TWeightArcMap): Boolean;
    function  FindInitSolution: Boolean;
    procedure InitPhase;
    procedure Discharge(aNode: PNode);
    procedure Execute;
    function  GetTotalCost: TCost;
    function  CreateArcFlows(out aTotalCost: TCost): TEdgeArray;
  public
    function  GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out aTotalCost: TCost): TWeight;
    function  GetMinCostFlow(aGraph: TGCostedInt64Net; aSource, aSink: SizeInt; aReqFlow: TWeight;
              out aTotalCost: TCost; out a: TEdgeArray): TWeight;
  end;



