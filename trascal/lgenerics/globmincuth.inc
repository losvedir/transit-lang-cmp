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
  TSWAdjList = specialize TGJoinableHashList<TWeightItem>;

  { TNIMinCutHelper: some implemenation of Nagamochi-Ibaraki minimum cut algorithm:
      H.Nagamochi and T.Ibaraki. "Computing Edge-Connectivity in Multigraphs and Capacitated Graphs" }
  TNIMinCutHelper = record
  private
  type
    TNiEdge = record
      Target: SizeInt;
      Weight,
      ScanRank: TWeight;
      Scanned: Boolean;
      constructor Create(aTarget: SizeInt; w: TWeight);
      property Key: SizeInt read Target;
    end;

    PNiEdge    = ^TNiEdge;
    TNiAdjList = specialize TGJoinableHashList<TNiEdge>;
    TEdgeQueue = specialize TGLiteQueue<TOrdIntPair>;
    TQueue     = specialize TGPairHeapMax<TWeightItem>;

  var
    FGraph: array of TNiAdjList;
    FCuts: array of TIntSet;
    FQueue: TQueue;
    FEdgeQueue: TEdgeQueue;
    FExistNodes,
    FInQueue: TBoolVector;
    FBestSet: TIntSet;
    FBestCut: TWeight;
    procedure ClearMarks;
    procedure Init(aGraph: TGInt64Net);
    procedure Init2(aGraph: TGInt64Net);
    procedure ShrinkEdge(aSource, aTarget: SizeInt);
    procedure ScanFirstSearch;
    procedure Shrink;
  public
    function  GetMinCut(aGraph: TGInt64Net): TWeight;
    function  GetMinCut(aGraph: TGInt64Net; out aCut: TIntSet): TWeight;
  end;
