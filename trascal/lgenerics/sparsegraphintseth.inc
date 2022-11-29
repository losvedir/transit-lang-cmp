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

  TIntSet = record
  private
    FItems: TIntArray;
    FCount: SizeInt;
    procedure Expand; inline;
    function  GetItem(aIndex: SizeInt): SizeInt; inline;
    class operator Initialize(var aSet: TIntSet);
  public
  type
    TEnumerator = record
    private
      pCurr,
      pLast: PSizeInt;
      function  GetCurrent: SizeInt; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: SizeInt read GetCurrent;
    end;

    procedure EnsureCapacity(aValue: SizeInt);
    procedure InitRange(aRange: SizeInt);
    function  GetEnumerator: TEnumerator; inline;
    function  ToArray: TIntArray; inline;
    procedure Assign(constref aSet: TIntSet);
    procedure AssignArray(constref a: TIntArray);
    procedure AssignList(aList: PAdjList);
    procedure Clear;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    function  FindFirst(out aValue: SizeInt): Boolean;
    function  Contains(aValue: SizeInt): Boolean; inline;
    function  ContainsAny(constref aSet: TIntSet): Boolean;
    function  ContainsAll(constref aSet: TIntSet): Boolean;
    function  Find(aValue: SizeInt): SizeInt;
    function  Add(aValue: SizeInt): Boolean;
    function  Add(constref a: TIntArray): SizeInt;
    function  Join(constref aSet: TIntSet): SizeInt;
    procedure Push(aValue: SizeInt); inline;
    function  Pop: SizeInt; inline;
    function  TryPop(out aValue: SizeInt): Boolean; inline;
    function  Last: SizeInt; inline;
  { preserves the order of the elements }
    procedure Subtract(constref aSet: TIntSet);
    procedure Subtract(aList: PAdjList);
    function  Difference(constref aSet: TIntSet): TIntSet; inline;
  { preserves the order of the elements }
    procedure Intersect(constref aSet: TIntSet);
    procedure Intersect(aList: PAdjList);
    function  Intersection(constref aSet: TIntSet): TIntSet; inline;
  { returns the number of elements in the intersection with aValue }
    function  IntersectionCount(constref aSet: TIntSet): SizeInt;
  { returns the number of elements in the intersection with PList }
    function  IntersectionCount(aList: PAdjList): SizeInt;
    function  Remove(aValue: SizeInt): Boolean;
  { preserves the order of the elements }
    procedure Delete(aValue: SizeInt);
    procedure Reverse; inline;
    property  Count: SizeInt read FCount;
    property  Items[aIndex: SizeInt]: SizeInt read GetItem; default;
  end;
  PIntSet = ^TIntSet;

  TIntSetArray = array of TIntSet;

  TSkeleton = record
  private
    FAdjLists: TIntSetArray;
    FEdgeCount: SizeInt;
    FDirected: Boolean;
    function  GetAdjList(aIndex: SizeInt): PIntSet; inline;
    function  GetDegree(aIndex: SizeInt): SizeInt; inline;
    function  GetVertexCount: SizeInt; inline;
  public
    constructor Create(aVertCount: SizeInt; aDirected: Boolean = False);
    constructor Create(constref s: TSkeleton);
    function ContainsEdge(aSrc, aDst: SizeInt): Boolean; inline;
    function AddEdge(aSrc, aDst: SizeInt): Boolean;
    function RemoveEdge(aSrc, aDst: SizeInt): Boolean;
    property VertexCount: SizeInt read GetVertexCount;
    property Directed: Boolean read FDirected;
    property EdgeCount: SizeInt read FEdgeCount;
    property Degree[aIndex: SizeInt]: SizeInt read GetDegree;
    property AdjLists[aIndex: SizeInt]: PIntSet read GetAdjList; default;
  end;

