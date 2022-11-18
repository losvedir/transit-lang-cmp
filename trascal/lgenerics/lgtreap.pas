{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some generic treap variants.                                            *
*                                                                           *
*   Copyright(c) 2019-2022 A.Koverdyaev(avk)                                *
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
unit lgTreap;

{$MODE OBJFPC}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}
interface

uses
  SysUtils, Math,
  lgUtils,
  lgBstUtils,
  {%H-}lgHelpers,
  lgStrConst;

type
  { TGLiteTreap implements randomized Cartesian BST(only);
    on assignment and when passed by value, the whole treap is copied;
      functor TCmpRel (comparison relation) must provide:
        class function Less([const[ref]] L, R: TKey): Boolean; }
  generic TGLiteTreap<TKey, TValue, TCmpRel> = record
  public
  type
    PNode = ^TNode;
    TNode = record
    private
      FLeft,
      FRight: PNode;
      FKey: TKey;
      FPrio: SizeUInt;
    public
      Value: TValue;
      property Left: PNode read FLeft;
      property Right: PNode read FRight;
      property Key: TKey read FKey;
    end;

    TUtil       = specialize TGBstUtil<TKey, TNode, TCmpRel>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
    FRoot: PNode;
    function  GetCount: SizeInt;
    function  GetHeight: SizeInt;
    class function  NewNode(const aKey: TKey): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
  { splits tree of aRoot into two subtrees, where min(R.Key) >= aKey }
    class procedure SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteTreap);
    class operator  Finalize(var aTreap: TGLiteTreap);
    class operator  Copy(constref aSrc: TGLiteTreap; var aDst: TGLiteTreap);
    class operator  AddRef(var aTreap: TGLiteTreap);
  public
    { splits aTreap so that L will contain all keys < aKey and  R will contain all keys >= aKey;
      aTreap becomes empty }
    class procedure Split(const aKey: TKey; var aTreap: TGLiteTreap; out L, R: TGLiteTreap); static;
    function  IsEmpty: Boolean; inline;          //O(1)
    procedure Clear;                             //O(N)
    function  ToArray: TEntryArray;              //O(N)
    function  Find(const aKey: TKey): PNode;     //O(LogN)
    function  CountOf(const aKey: TKey): SizeInt;//O(N)
    function  Add(const aKey: TKey): PNode;      //O(LogN)
    function  Remove(const aKey: TKey): Boolean; //O(LogN)
    function  Remove(const aKey: TKey; out aValue: TValue): Boolean; //O(LogN)
  { splits treap so that aTreap will contain all elements with keys >= aKey }
    procedure Split(const aKey: TKey; out aTreap: TGLiteTreap);//O(LogN)
    property  Root: PNode read FRoot;            //O(1)
    property  Count: SizeInt read GetCount;      //O(N)
    property  Height: SizeInt read GetHeight;    //O(N)
  end;

  { TGLiteIdxTreap implements randomized Cartesian BST which allows indexing access
      (IOW rank and N-th order statistics)
      on assignment and when passed by value, the whole treap is copied;
        functor TCmpRel (comparison relation) must provide:
          class function Less([const[ref]] L, R: TKey): Boolean; }
  generic TGLiteIdxTreap<TKey, TValue, TCmpRel> = record
  public
  type
    PNode = ^TNode;
    TNode = record
    private
      FLeft,
      FRight: PNode;
      FKey: TKey;
      FPrio: SizeUInt;
      FSize: SizeInt;
    public
      Value: TValue;
      property Left: PNode read FLeft;
      property Right: PNode read FRight;
      property Key: TKey read FKey;
      property Size: SizeInt read FSize;
    end;

    TUtil       = specialize TGIndexedBstUtil<TKey, TNode, TCmpRel>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    function  GetItem(aIndex: SizeInt): PNode; inline;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    class function  NewNode(const aKey: TKey): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateSize(aNode: PNode); static; inline;
    class procedure SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteIdxTreap);
    class operator  Finalize(var aTreap: TGLiteIdxTreap);
    class operator  Copy(constref aSrc: TGLiteIdxTreap; var aDst: TGLiteIdxTreap);
    class operator  AddRef(var aTreap: TGLiteIdxTreap); inline;
  public
  { splits aTreap so that L will contain all keys < aKey and  R will contain all keys >= aKey;
    aTreap becomes empty }
    class procedure Split(const aKey: TKey; var aTreap: TGLiteIdxTreap; out L, R: TGLiteIdxTreap); static;
    function  IsEmpty: Boolean; inline;           //O(1)
    procedure Clear;                              //O(N)
    function  ToArray: TEntryArray;               //O(N)
    function  Find(const aKey: TKey): PNode;      //O(LogN)
    function  IndexOf(const aKey: TKey): SizeInt; inline;//O(LogN)
    function  CountOf(const aKey: TKey): SizeInt; //O(LogN)
    function  Add(const aKey: TKey): PNode;       //O(LogN)
    function  Remove(const aKey: TKey): Boolean;  //O(LogN)
    function  Remove(const aKey: TKey; out aValue: TValue): Boolean;//O(LogN)
  { splits treap so that aTreap will contain all elements with keys >= aKey }
    procedure Split(const aKey: TKey; out aTreap: TGLiteIdxTreap);  //O(LogN)
    property  Root: PNode read FRoot;             //O(1)
    property  Count: SizeInt read GetCount;       //O(1)
    property  Height: SizeInt read GetHeight;     //O(N)
    property  Items[aIndex: SizeInt]: PNode read GetItem; default;//O(LogN)
  end;

  { TGLiteSegmentTreap implements randomized Cartesian BST with unique keys which allows
    indexing access and allows find the value of the monoid function on an arbitrary
    range of keys in O(log N); on assignment and when passed by value, the whole treap is copied;
      functor TCmpRel (comparision relation) must provide:
        class function Less([const[ref]] L, R: TKey): Boolean;
      functor TValMonoid must provide:
        class field/property/function Identity: TValue; - neutral element of the monoid;
        associative dyadic function BinOp([const[ref]] L, R: TValue): TValue; }
  generic TGLiteSegmentTreap<TKey, TValue, TCmpRel, TValMonoid> = record
  public
  type
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
  type
    PNode = ^TNode;
    TNode = record
      Left,
      Right: PNode;
      Key: TKey;
      Prio: SizeUInt;
      Size: SizeInt;
      CacheVal,
      Value: TValue;
    end;
    TUtil = specialize TGIndexedBstUtil<TKey, TNode, TCmpRel>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt; inline;
    function  GetValue(const aKey: TKey): TValue;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    function  GetEntry(aIndex: SizeInt): TEntry;
    procedure SetValue(const aKey: TKey; const aValue: TValue);

    class function  NewNode(const aKey: TKey; const aValue: TValue): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateNode(aNode: PNode); static; inline;
    class procedure UpdateCache(aNode: PNode); static; inline;
    class function  UpdateValue(aRoot: PNode; const aKey: TKey; const aValue: TValue): Boolean; static;
    class procedure SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteSegmentTreap);
    class operator  Finalize(var aTreap: TGLiteSegmentTreap);
    class operator  Copy(constref aSrc: TGLiteSegmentTreap; var aDst: TGLiteSegmentTreap);
    class operator  AddRef(var aTreap: TGLiteSegmentTreap); inline;
  public
    class procedure Split(const aKey: TKey; var aTreap: TGLiteSegmentTreap;
                          out L, R: TGLiteSegmentTreap); static;
    function  IsEmpty: Boolean; inline;                      //O(1)
    procedure Clear;                                         //O(N)
    function  ToArray: TEntryArray;                          //O(N)
    function  Contains(const aKey: TKey): Boolean;           //O(LogN)
    function  Find(const aKey: TKey; out aValue: TValue): Boolean; //O(LogN)
    function  FindLess(const aKey: TKey; out aLess: TKey): Boolean;
    function  FindLessOrEqual(const aKey: TKey; out aLessOrEq: TKey): Boolean;
    function  FindGreater(const aKey: TKey; out aGreater: TKey): Boolean;
    function  FindGreaterOrEqual(const aKey: TKey; out aGreaterOrEq: TKey): Boolean;
    function  IndexOf(const aKey: TKey): SizeInt; inline;    //O(LogN)
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;//O(LogN)
    function  Add(const e: TEntry): Boolean; inline;         //O(LogN)
    function  Remove(const aKey: TKey): Boolean;             //O(LogN)
    function  Remove(const aKey: TKey; out aValue: TValue): Boolean;  //O(LogN)
    procedure Split(const aKey: TKey; out aTreap: TGLiteSegmentTreap);//O(LogN)
  { returns value of the monoid function on the segment[L, R](indices);
    raises exception if L or R out of bounds }
    function  RangeQueryI(L, R: SizeInt): TValue;            //O(LogN)
  { returns value of the monoid function on the half-open interval[L, R) }
    function  RangeQuery(const L, R: TKey): TValue;          //O(LogN)
  { returns value of the monoid function on the half-open interval[L, R)
    and the number of elements that fit into this interval in aCount }
    function  RangeQuery(const L, R: TKey; out aCount: SizeInt): TValue;
  { returns value of the monoid function on the segment[0, aIndex](indices);
    raises exception if aIndex out of bounds }
    function  HeadQueryI(aIndex: SizeInt): TValue;           //O(LogN)
  { returns value of the monoid function on the half-open interval[Lowest(key), aKey) }
    function  HeadQuery(const aKey: TKey): TValue;           //O(LogN)
  { returns value of the monoid function on the half-open interval[Lowest(key), aKey)
    and the number of elements that fit into this interval in aCount }
    function  HeadQuery(const aKey: TKey; out aCount: SizeInt): TValue;
  { returns value of the monoid function on the segment[aIndex, Pred(Count)](indices);
    raises exception if aIndex out of bounds }
    function  TailQueryI(aIndex: SizeInt): TValue;           //O(LogN)
  { returns value of the monoid function on the segment[aKey, Highest(key)] }
    function  TailQuery(const aKey: TKey): TValue;           //O(LogN)
  { returns value of the monoid function on the segment[aKey, Highest(key)]
    and the number of elements that fit into this interval in aCount }
    function  TailQuery(const aKey: TKey; out aCount: SizeInt): TValue;
    property  Count: SizeInt read GetCount;                  //O(1)
    property  Height: SizeInt read GetHeight;                //O(N)
    property  Entries[aIndex: SizeInt]: TEntry read GetEntry;//O(LogN)
  { if not contains aKey then read returns TValMonoid.Identity }
    property  Values[const aKey: TKey]: TValue read GetValue write SetValue; default;//O(LogN)
  end;

  { TGLiteImplicitTreap implements randomized Cartesian tree which mimics
    an array with most operations in O(LogN); on assignment and when passed by value,
    the whole treap is copied; }
  generic TGLiteImplicitTreap<T> = record
  public
  type
    TArray = array of T;

  private
  type
    PNode = ^TNode;
    TNode = record
    private
      Left,
      Right: PNode;
      Prio: SizeUInt;
      Size: SizeInt;
      Value: T;
      property Key: SizeInt read Size;
    end;
    TUtil = specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    procedure CheckInsertRange(aIndex: SizeInt); inline;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    class function  NewNode(const aValue: T): PNode; static; inline;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateSize(aNode: PNode); static; inline;
    class procedure SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T); static;
    class operator  Initialize(var aTreap: TGLiteImplicitTreap);
    class operator  Finalize(var aTreap: TGLiteImplicitTreap);
    class operator  Copy(constref aSrc: TGLiteImplicitTreap; var aDst: TGLiteImplicitTreap);
    class operator  AddRef(var aTreap: TGLiteImplicitTreap); inline;
  public
    class procedure Split(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap;
                          out L, R: TGLiteImplicitTreap); static;
    function  IsEmpty: Boolean; inline;                //O(1)
    procedure Clear;                                   //O(N)
    function  ToArray: TArray;                         //O(N)
    function  Add(const aValue: T): SizeInt;           //O(LogN)
    procedure Insert(aIndex: SizeInt; const aValue: T);//O(LogN)
    procedure Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap);
    function  Delete(aIndex: SizeInt): T;              //O(LogN)
    procedure Split(aIndex: SizeInt; out aTreap: TGLiteImplicitTreap);
    procedure Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitTreap);//O(LogN)
    procedure Merge(var aTreap: TGLiteImplicitTreap);  //O(LogN)
    procedure RotateLeft(aDist: SizeInt);              //O(LogN)
    procedure RotateRight(aDist: SizeInt);             //O(LogN)
    property  Count: SizeInt read GetCount;            //O(1)
    property  Height: SizeInt read GetHeight;          //O(N)
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;  //O(LogN)
  end;

  { TGLiteImplSegmentTreap implements randomized Cartesian tree which mimics an array;
    it allows:
      - add an element to the array in O(log N);
      - update a single element of an array in O(log N);
      - add an arbitrary range of elements to the array in O(log N);
      - find the value: TResult of the monoid function on an arbitrary range
        of array elements in O(log N);
      type TResult must provide an assignment operator (TResult := T)
      functor TMonoid must provide:
        class field/property/function Identity: TResult; - neutral element of the monoid;
        associative dyadic function BinOp([const[ref]] L, R: TResult): TResult;
    on assignment and when passed by value, the whole treap is copied; }
  generic TGLiteImplSegmentTreap<T, TResult, TMonoid> = record
  public
  type
    TArray = array of T;

  private
  type
    PNode = ^TNode;
    TNode = record
    private
      Left,
      Right: PNode;
      Prio: SizeUInt;
      Size: SizeInt;
      Value: T;
      CacheVal: TResult;
      property Key: SizeInt read Size;
    end;
    TUtil = specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    procedure CheckInsertRange(aIndex: SizeInt); inline;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    class function  NewNode(const aValue: T): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateNode(aNode: PNode); static; inline;
    class procedure UpdateCache(aNode: PNode); static; inline;
    class procedure UpdateValue(aIndex: SizeInt; aRoot: PNode; const aValue: T); static;
    class procedure SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T); static;
    class operator  Initialize(var aTreap: TGLiteImplSegmentTreap);
    class operator  Finalize(var aTreap: TGLiteImplSegmentTreap);
    class operator  Copy(constref aSrc: TGLiteImplSegmentTreap; var aDst: TGLiteImplSegmentTreap);
    class operator  AddRef(var aTreap: TGLiteImplSegmentTreap); inline;
  public
    class procedure Split(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap;
                          out L, R: TGLiteImplSegmentTreap); static;
    function  IsEmpty: Boolean; inline;                 //O(1)
    procedure Clear;                                    //O(N)
    function  ToArray: TArray;                          //O(N)
    function  Add(const aValue: T): SizeInt;            //O(LogN)
    procedure Insert(aIndex: SizeInt; const aValue: T); //O(LogN)
    procedure Insert(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap);       //O(LogN)
    function  Delete(aIndex: SizeInt): T;               //O(LogN)
    procedure Split(aIndex: SizeInt; out aTreap: TGLiteImplSegmentTreap);        //O(LogN)
    procedure Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplSegmentTreap);//O(LogN)
    procedure Merge(var aTreap: TGLiteImplSegmentTreap);//O(LogN)
    procedure RotateLeft(aDist: SizeInt);               //O(LogN)
    procedure RotateRight(aDist: SizeInt);              //O(LogN)
  { returns value of the monoid function on the segment[L, R];
    raises exception if L or R out of bounds }
    function  RangeQuery(L, R: SizeInt): TResult;       //O(LogN)
  { returns value of the monoid function on the segment[0, aIndex];
    raises exception if aIndex out of bounds }
    function  HeadQuery(aIndex: SizeInt): TResult;      //O(LogN)
  { returns value of the monoid function on the segment[aIndex, Pred(Count)];
    raises exception if aIndex out of bounds }
    function  TailQuery(aIndex: SizeInt): TResult;      //O(LogN)
    property  Count: SizeInt read GetCount;             //O(1)
    property  Height: SizeInt read GetHeight;           //O(N)
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;     //O(LogN)
  end;

  { TGLiteImplicitSegTreap implements randomized Cartesian tree which mimics an array;
    it allows:
      - add an element to the array in O(log N);
      - update a single element of an array in O(log N);
      - add an arbitrary range of elements to the array in O(log N);
      - reverse an arbitrary range of elements to the array in O(log N);
      - modify an arbitrary range of elements of an array by some constant value in O(log N);
      - find the value of the monoid function on an arbitrary range of array elements in O(log N);
      functor TMonoid must provide:
        class field/property/function Identity: T; - neutral element of the monoid;
        associative dyadic function BinOp([const[ref]] L, R: T): T; - base monoid operation;
        additional operation AddConst must be associative, and operations must satisfy the
        distributive property:
        function AddConst([const[ref]] aValue, aConst: T; aSize: SizeInt = 1): T;
        class field/property/function ZeroConst: T; - neutral element of the additional operation;
        function IsZeroConst([const[ref]] aValue: T): Boolean; - helper function;
    on assignment and when passed by value, the whole treap is copied; }
  generic TGLiteImplicitSegTreap<T, TMonoid> = record
  public
  type
    TArray = array of T;

  private
  type
    PNode = ^TNode;

    TNode = record
    private
    const
      REV_FLAG  = SizeInt(SizeInt(1) shl Pred(BitSizeOf(SizeInt)));
      SIZE_MASK = SizeInt(Pred(SizeUInt(REV_FLAG)));
    var
      FSize: SizeInt;
      function  GetReversed: Boolean; inline;
      function  GetSize: SizeInt; inline;
      procedure SetReversed(aValue: Boolean); inline;
      procedure SetSize(aValue: SizeInt); inline;
    public
      Left,
      Right: PNode;
      Prio: SizeUInt;
      AddVal,
      CacheVal,
      Value: T;
      property Size: SizeInt read GetSize write SetSize;
      property Reversed: Boolean read GetReversed write SetReversed;
      property Key: SizeInt read GetSize;
    end;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    procedure CheckInsertRange(aIndex: SizeInt); inline;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    class function  NewNode(const aValue: T): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateNode(aNode: PNode); static; inline;
    class procedure Push(aNode: PNode); static; inline;
    class procedure SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class operator  Initialize(var aTreap: TGLiteImplicitSegTreap);
    class operator  Finalize(var aTreap: TGLiteImplicitSegTreap);
    class operator  Copy(constref aSrc: TGLiteImplicitSegTreap; var aDst: TGLiteImplicitSegTreap);
    class operator  AddRef(var aTreap: TGLiteImplicitSegTreap); inline;
  public
    class procedure Split(aIndex: SizeInt; var aTreap: TGLiteImplicitSegTreap;
                          out L, R: TGLiteImplicitSegTreap); static;             //O(LogN)
    function  IsEmpty: Boolean; inline;                   //O(1)
    procedure Clear;                                      //O(N)
    function  ToArray: TArray;                            //O(N)
    function  Add(const aValue: T): SizeInt;              //O(LogN)
    procedure Insert(aIndex: SizeInt; const aValue: T);   //O(LogN)
    procedure Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitSegTreap);       //O(LogN)
    function  Delete(aIndex: SizeInt): T;                 //O(LogN)
    function  Delete(aIndex, aCount: SizeInt): SizeInt;   //O(LogN)
    procedure Split(aIndex: SizeInt; out aTreap: TGLiteImplicitSegTreap);        //O(LogN)
    procedure Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitSegTreap);//O(LogN)
    procedure Merge(var aTreap: TGLiteImplicitSegTreap);  //O(LogN)
    procedure RotateLeft(aDist: SizeInt);                 //O(LogN)
    procedure RotateRight(aDist: SizeInt);                //O(LogN)
    procedure Reverse;                                    //O(LogN)
    procedure Reverse(aFrom, aCount: SizeInt);            //O(LogN)
    procedure RangeUpdate(L, R: SizeInt; const aConst: T);//O(LogN)
  { returns value of the monoid function on the segment[L, R];
    raises exception if L or R out of bounds }
    function  RangeQuery(L, R: SizeInt): T;               //O(LogN)
  { returns value of the monoid function on the segment[0, aIndex];
    raises exception if aIndex out of bounds }
    function  HeadQuery(aIndex: SizeInt): T;              //O(LogN)
  { returns value of the monoid function on the segment[aIndex, Pred(Count)];
    raises exception if aIndex out of bounds }
    function  TailQuery(aIndex: SizeInt): T;              //O(LogN)
    property  Count: SizeInt read GetCount;               //O(1)
    property  Height: SizeInt read GetHeight;             //O(N)
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default; //O(LogN)
  end;

  function NextRandomQWord: QWord; inline;

implementation
{$B-}{$COPERATORS ON}

function NextRandomQWord: QWord;
begin
  Result := SmNextRandom;
end;

{ TGLiteTreap }

function TGLiteTreap.GetCount: SizeInt;
begin
  if FRoot <> nil then
    exit(TUtil.GetTreeSize(FRoot));
  Result := 0;
end;

function TGLiteTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

class function TGLiteTreap.NewNode(const aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FPrio := SizeUInt(NextRandomQWord);
end;

class function TGLiteTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.FRight);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteTreap.SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Less(aRoot^.Key, aKey) then
        begin
          L := aRoot;
          SplitNode(aKey, L^.FRight, L^.FRight, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.FLeft, L, R^.FLeft);
        end;
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      if L^.FPrio > R^.FPrio then
        begin
          L^.FRight := MergeNode(L^.FRight, R);
          Result := L;
        end
      else
        begin
          R^.FLeft := MergeNode(L, R^.FLeft);
          Result := R;
        end;
end;

class procedure TGLiteTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.FPrio < aNode^.FPrio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.FLeft, aNode^.FRight);
          aRoot := aNode;
        end
      else
        if TCmpRel.Less(aNode^.Key, aRoot^.Key) then
          AddNode(aRoot^.FLeft, aNode)
        else
          AddNode(aRoot^.FRight, aNode);
    end
  else
    aRoot := aNode;
end;


class function TGLiteTreap.RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
begin
  if aRoot <> nil then
    if TCmpRel.Less(aKey, aRoot^.Key) then
      exit(RemoveNode(aKey, aRoot^.FLeft))
    else
      if TCmpRel.Less(aRoot^.Key, aKey) then
        exit(RemoveNode(aKey, aRoot^.FRight))
      else
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
          TUtil.FreeNode(Found);
          exit(True);
        end;
  Result := False;
end;

class function TGLiteTreap.RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
begin
  if aRoot <> nil then
    if TCmpRel.Less(aKey, aRoot^.Key) then
      exit(RemoveNode(aKey, aRoot^.FLeft, v))
    else
      if TCmpRel.Less(aRoot^.Key, aKey) then
        exit(RemoveNode(aKey, aRoot^.FRight, v))
      else
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
          v := Found^.Value;
          TUtil.FreeNode(Found);
          exit(True);
        end;
  Result := False;
end;

class operator TGLiteTreap.Initialize(var aTreap: TGLiteTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteTreap.Finalize(var aTreap: TGLiteTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteTreap.Copy(constref aSrc: TGLiteTreap; var aDst: TGLiteTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteTreap.AddRef(var aTreap: TGLiteTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteTreap.Split(const aKey: TKey; var aTreap: TGLiteTreap; out L, R: TGLiteTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        if System.Length(a) = I then
          System.SetLength(a, I * 2);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.FRight);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, ARRAY_INITIAL_SIZE);
      Visit(FRoot);
      System.SetLength(a, I);
    end;
  Result := a;
end;

function TGLiteTreap.Find(const aKey: TKey): PNode;
begin
  if FRoot <> nil then
    exit(TUtil.FindKey(FRoot, aKey));
  Result := nil;
end;

function TGLiteTreap.CountOf(const aKey: TKey): SizeInt;
var
  L, M, R, Gt: PNode;
begin
  if FRoot <> nil then
    begin
      Gt := TUtil.GetGreater(FRoot, aKey);
      SplitNode(aKey, FRoot, L, R);
      if Gt <> nil then
        begin
          SplitNode(Gt^.Key, R, M, R);
          Result := TUtil.GetTreeSize(M);
          FRoot := MergeNode(MergeNode(L, M), R);
        end
      else
        begin
          Result := TUtil.GetTreeSize(R);
          FRoot := MergeNode(L, R);
        end;
    end
  else
    Result := 0;
end;

function TGLiteTreap.Add(const aKey: TKey): PNode;
begin
  Result := NewNode(aKey);
  if FRoot <> nil then
    AddNode(FRoot, Result)
  else
    FRoot := Result;
end;

function TGLiteTreap.Remove(const aKey: TKey): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteTreap.Remove(const aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteTreap.Split(const aKey: TKey; out aTreap: TGLiteTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

{ TGLiteIdxTreap }

function TGLiteIdxTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteIdxTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteIdxTreap.GetItem(aIndex: SizeInt): PNode;
begin
  Result := TUtil.GetByIndex(FRoot, aIndex);
end;

procedure TGLiteIdxTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

class function TGLiteIdxTreap.NewNode(const aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FPrio := SizeUInt(NextRandomQWord);
  Result^.FSize := 1;
end;

class function TGLiteIdxTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteIdxTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.FRight);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteIdxTreap.UpdateSize(aNode: PNode);
begin
  with aNode^ do
    begin
      FSize := 1;
      if Left <> nil then
        FSize += Left^.FSize;
      if Right <> nil then
        FSize += Right^.FSize;
    end;
end;

class procedure TGLiteIdxTreap.SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Less(aRoot^.Key, aKey) then
        begin
          L := aRoot;
          SplitNode(aKey, L^.FRight, L^.FRight, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.FLeft, L, R^.FLeft);
        end;
      UpdateSize(aRoot);
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteIdxTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.FPrio > R^.FPrio then
          begin
            L^.FRight := MergeNode(L^.FRight, R);
            Result := L;
          end
        else
          begin
            R^.FLeft := MergeNode(L, R^.FLeft);
            Result := R;
          end;
        UpdateSize(Result);
      end;
end;

class procedure TGLiteIdxTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.FPrio < aNode^.FPrio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.FLeft, aNode^.FRight);
          aRoot := aNode;
        end
      else
        if TCmpRel.Less(aNode^.Key, aRoot^.Key) then
          AddNode(aRoot^.FLeft, aNode)
        else
          AddNode(aRoot^.FRight, aNode);
      UpdateSize(aRoot);
    end
  else
    aRoot := aNode;
end;

class function TGLiteIdxTreap.RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
begin
  if aRoot = nil then exit(False);
  if TCmpRel.Less(aKey, aRoot^.Key) then
    begin
      Result := RemoveNode(aKey, aRoot^.FLeft);
      if Result and (aRoot <> nil) then
        UpdateSize(aRoot);
    end
  else
    if TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := RemoveNode(aKey, aRoot^.FRight);
        if Result and (aRoot <> nil) then
          UpdateSize(aRoot);
      end
    else
      begin
        Found := aRoot;
        aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
        TUtil.FreeNode(Found);
        Result := True;
      end;
end;

class function TGLiteIdxTreap.RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
begin
  if aRoot = nil then exit(False);
  if TCmpRel.Less(aKey, aRoot^.Key) then
    begin
      Result := RemoveNode(aKey, aRoot^.FLeft, v);
      if Result and (aRoot <> nil) then
        UpdateSize(aRoot);
    end
  else
    if TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := RemoveNode(aKey, aRoot^.FRight, v);
        if Result and (aRoot <> nil) then
          UpdateSize(aRoot);
      end
    else
      begin
        Found := aRoot;
        aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
        v := Found^.Value;
        TUtil.FreeNode(Found);
        Result := True;
      end;
end;

class operator TGLiteIdxTreap.Initialize(var aTreap: TGLiteIdxTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteIdxTreap.Finalize(var aTreap: TGLiteIdxTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteIdxTreap.Copy(constref aSrc: TGLiteIdxTreap; var aDst: TGLiteIdxTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteIdxTreap.AddRef(var aTreap: TGLiteIdxTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteIdxTreap.Split(const aKey: TKey; var aTreap: TGLiteIdxTreap;
  out L, R: TGLiteIdxTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteIdxTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteIdxTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteIdxTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.FRight);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteIdxTreap.Find(const aKey: TKey): PNode;
begin
  if FRoot <> nil then
    exit(TUtil.FindKey(FRoot, aKey));
  Result := nil;
end;

function TGLiteIdxTreap.IndexOf(const aKey: TKey): SizeInt;
begin
  Result := TUtil.GetKeyIndex(FRoot, aKey);
end;

function TGLiteIdxTreap.CountOf(const aKey: TKey): SizeInt;
var
  L, M, R, Gt: PNode;
begin
  if FRoot <> nil then
    begin
      Gt := TUtil.GetGreater(FRoot, aKey);
      SplitNode(aKey, FRoot, L, R);
      if Gt <> nil then
        begin
          SplitNode(Gt^.Key, R, M, R);
          Result := TUtil.GetNodeSize(M);
          FRoot := MergeNode(MergeNode(L, M), R);
        end
      else
        begin
          Result := TUtil.GetNodeSize(R);
          FRoot := MergeNode(L, R);
        end;
    end
  else
    Result := 0;
end;

function TGLiteIdxTreap.Add(const aKey: TKey): PNode;
begin
  Result := NewNode(aKey);
  if FRoot <> nil then
    AddNode(FRoot, Result)
  else
    FRoot := Result;
end;

function TGLiteIdxTreap.Remove(const aKey: TKey): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteIdxTreap.Remove(const aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteIdxTreap.Split(const aKey: TKey; out aTreap: TGLiteIdxTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

{ TGLiteSegmentTreap }

function TGLiteSegmentTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteSegmentTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteSegmentTreap.GetValue(const aKey: TKey): TValue;
begin
  if not Find(aKey, Result) then
    Result := TValMonoid.Identity;
end;

procedure TGLiteSegmentTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteSegmentTreap.GetEntry(aIndex: SizeInt): TEntry;
begin
  CheckIndexRange(aIndex);
  with TUtil.GetByIndex(FRoot, aIndex)^ do
    Result := TEntry.Create(Key, Value);
end;

class function TGLiteSegmentTreap.NewNode(const aKey: TKey; const aValue: TValue): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Key := aKey;
  Result^.Prio := SizeUInt(NextRandomQWord);
  Result^.Size := 1;
  Result^.CacheVal := aValue;
  Result^.Value := aValue;
end;

class function TGLiteSegmentTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteSegmentTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Key, aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

procedure TGLiteSegmentTreap.SetValue(const aKey: TKey; const aValue: TValue);
begin
  if not Add(aKey, aValue) then
    UpdateValue(FRoot, aKey, aValue);
end;

class procedure TGLiteSegmentTreap.UpdateNode(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      CacheVal := aNode^.Value;
      if Left <> nil then
        begin
          Size += Left^.Size;
          CacheVal := TValMonoid.BinOp(CacheVal, Left^.CacheVal);
        end;
      if Right <> nil then
        begin
          Size += Right^.Size;
          CacheVal := TValMonoid.BinOp(CacheVal, Right^.CacheVal);
        end;
    end;
end;

class procedure TGLiteSegmentTreap.UpdateCache(aNode: PNode);
begin
  with aNode^ do
    begin
      CacheVal := aNode^.Value;
      if Left <> nil then
        CacheVal := TValMonoid.BinOp(CacheVal, Left^.CacheVal);
      if Right <> nil then
        CacheVal := TValMonoid.BinOp(CacheVal, Right^.CacheVal);
    end;
end;

class function TGLiteSegmentTreap.UpdateValue(aRoot: PNode; const aKey: TKey;
  const aValue: TValue): Boolean;
begin
  if aRoot = nil then exit(False);
  if TCmpRel.Less(aKey, aRoot^.Key) then
    Result := UpdateValue(aRoot^.Left, aKey, aValue)
  else
    if TCmpRel.Less(aRoot^.Key, aKey) then
      Result := UpdateValue(aRoot^.Right, aKey, aValue)
    else
      begin
        aRoot^.Value := aValue;
        Result := True;
      end;
  if Result then
    UpdateCache(aRoot);
end;

class procedure TGLiteSegmentTreap.SplitNode(const aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Less(aRoot^.Key, aKey) then
        begin
          L := aRoot;
          SplitNode(aKey, L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.Left, L, R^.Left);
        end;
      UpdateNode(aRoot);
    end
  else
    begin
      L := nil;
      R := nil;
    end;
end;

class function TGLiteSegmentTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateNode(Result);
      end;
end;

class procedure TGLiteSegmentTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.Prio < aNode^.Prio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.Left, aNode^.Right);
          aRoot := aNode;
        end
      else
        if TCmpRel.Less(aNode^.Key, aRoot^.Key) then
          AddNode(aRoot^.Left, aNode)
        else
          AddNode(aRoot^.Right, aNode);
      UpdateNode(aRoot);
    end
  else
    aRoot := aNode;
end;

class function TGLiteSegmentTreap.RemoveNode(const aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
begin
  if aRoot = nil then exit(False);
  if TCmpRel.Less(aKey, aRoot^.Key) then
    begin
      Result := RemoveNode(aKey, aRoot^.Left);
      if Result then
        UpdateNode(aRoot);
    end
  else
    if TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := RemoveNode(aKey, aRoot^.Right);
        if Result then
          UpdateNode(aRoot);
      end
    else
      begin
        Found := aRoot;
        aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
        TUtil.FreeNode(Found);
        Result := True;
      end;
end;

class function TGLiteSegmentTreap.RemoveNode(const aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
begin
  if aRoot = nil then exit(False);
  if TCmpRel.Less(aKey, aRoot^.Key) then
    begin
      Result := RemoveNode(aKey, aRoot^.Left, v);
      if Result then
        UpdateNode(aRoot);
    end
  else
    if TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := RemoveNode(aKey, aRoot^.Right, v);
        if Result then
          UpdateNode(aRoot);
      end
    else
      begin
        Found := aRoot;
        aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
        v := Found^.Value;
        TUtil.FreeNode(Found);
        Result := True;
      end;
end;

class operator TGLiteSegmentTreap.Initialize(var aTreap: TGLiteSegmentTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteSegmentTreap.Finalize(var aTreap: TGLiteSegmentTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteSegmentTreap.Copy(constref aSrc: TGLiteSegmentTreap; var aDst: TGLiteSegmentTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteSegmentTreap.AddRef(var aTreap: TGLiteSegmentTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteSegmentTreap.Split(const aKey: TKey; var aTreap: TGLiteSegmentTreap; out L,
  R: TGLiteSegmentTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteSegmentTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteSegmentTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteSegmentTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteSegmentTreap.Contains(const aKey: TKey): Boolean;
begin
  Result := TUtil.FindKey(FRoot, aKey) <> nil;
end;

function TGLiteSegmentTreap.Find(const aKey: TKey; out aValue: TValue): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.FindKey(FRoot, aKey);
      if Node <> nil then
        begin
          aValue := Node^.Value;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.FindLess(const aKey: TKey; out aLess: TKey): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.GetLess(FRoot, aKey);
      if Node <> nil then
        begin
          aLess := Node^.Key;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.FindLessOrEqual(const aKey: TKey; out aLessOrEq: TKey): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.GetLessOrEqual(FRoot, aKey);
      if Node <> nil then
        begin
          aLessOrEq := Node^.Key;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.FindGreater(const aKey: TKey; out aGreater: TKey): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.GetGreater(FRoot, aKey);
      if Node <> nil then
        begin
          aGreater := Node^.Key;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.FindGreaterOrEqual(const aKey: TKey; out aGreaterOrEq: TKey): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.GetGreaterOrEqual(FRoot, aKey);
      if Node <> nil then
        begin
          aGreaterOrEq := Node^.Key;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.IndexOf(const aKey: TKey): SizeInt;
begin
  Result := TUtil.GetKeyIndex(FRoot, aKey);
end;

function TGLiteSegmentTreap.Add(const aKey: TKey; const aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    begin
      if Contains(aKey) then
        exit(False);
      AddNode(FRoot, NewNode(aKey, aValue));
    end
  else
    FRoot := NewNode(aKey, aValue);
  Result := True;
end;

function TGLiteSegmentTreap.Add(const e: TEntry): Boolean;
begin
  Result := Add(e.Key, e.Value);
end;

function TGLiteSegmentTreap.Remove(const aKey: TKey): Boolean;
begin
  if FRoot <> nil  then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteSegmentTreap.Remove(const aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil  then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteSegmentTreap.Split(const aKey: TKey; out aTreap: TGLiteSegmentTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

function TGLiteSegmentTreap.RangeQueryI(L, R: SizeInt): TValue;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    if R < Pred(FRoot^.Size) then
      exit(RangeQuery(TUtil.GetByIndex(FRoot, L)^.Key, TUtil.GetByIndex(FRoot, Succ(R))^.Key))
    else
      exit(TailQuery(TUtil.GetByIndex(FRoot, L)^.Key));
  Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.RangeQuery(const L, R: TKey): TValue;
var
  pL, pM, pR: PNode;
begin
  if (FRoot <> nil) and TCmpRel.Less(L, R) then
    begin
      SplitNode(L, FRoot, pL, pR);
      SplitNode(R, pR, pM, pR);
      if pM <> nil then
        Result := pM^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(MergeNode(pL, pM), pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.RangeQuery(const L, R: TKey; out aCount: SizeInt): TValue;
var
  pL, pM, pR: PNode;
begin
  aCount := 0;
  if (FRoot <> nil) and TCmpRel.Less(L, R) then
    begin
      SplitNode(L, FRoot, pL, pR);
      SplitNode(R, pR, pM, pR);
      if pM <> nil then
        begin
          Result := pM^.CacheVal;
          aCount := pM^.Size;
        end
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(MergeNode(pL, pM), pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.HeadQueryI(aIndex: SizeInt): TValue;
begin
  CheckIndexRange(aIndex);
  if aIndex < Pred(FRoot^.Size) then
    Result := HeadQuery(TUtil.GetByIndex(FRoot, Succ(aIndex))^.Key)
  else
    Result := FRoot^.CacheVal;
end;

function TGLiteSegmentTreap.HeadQuery(const aKey: TKey): TValue;
var
  pL, pR: PNode;
begin
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pL <> nil then
        Result := pL^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.HeadQuery(const aKey: TKey; out aCount: SizeInt): TValue;
var
  pL, pR: PNode;
begin
  aCount := 0;
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pL <> nil then
        begin
          Result := pL^.CacheVal;
          aCount := pL^.Size;
        end
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.TailQueryI(aIndex: SizeInt): TValue;
begin
  CheckIndexRange(aIndex);
  Result := TailQuery(TUtil.GetByIndex(FRoot, aIndex)^.Key);
end;

function TGLiteSegmentTreap.TailQuery(const aKey: TKey): TValue;
var
  pL, pR: PNode;
begin
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pR <> nil then
        Result := pR^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.TailQuery(const aKey: TKey; out aCount: SizeInt): TValue;
var
  pL, pR: PNode;
begin
  aCount := 0;
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pR <> nil then
        begin
          Result := pR^.CacheVal;
          aCount := pR^.Size;
        end
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

{ TGLiteImplicitTreap }

function TGLiteImplicitTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteImplicitTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

procedure TGLiteImplicitTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteImplicitTreap.CheckInsertRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) > SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteImplicitTreap.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := TUtil.GetByIndex(FRoot, aIndex)^.Value;
end;

procedure TGLiteImplicitTreap.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  TUtil.GetByIndex(FRoot, aIndex)^.Value := aValue;
end;

class function TGLiteImplicitTreap.NewNode(const aValue: T): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Prio := SizeUInt(NextRandomQWord);
  Result^.Size := 1;
  Result^.Value := aValue;
end;

class function TGLiteImplicitTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteImplicitTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  if aRoot = nil then exit(nil);
  Tmp.Clear;
  Visit(aRoot);
  Result := Tmp.FRoot;
  Tmp.FRoot := nil;
end;

class procedure TGLiteImplicitTreap.UpdateSize(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      if Left <> nil then
        Size += Left^.Size;
      if Right <> nil then
        Size += Right^.Size;
    end;
end;

class procedure TGLiteImplicitTreap.SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode);
var
  CurrIdx: SizeInt;
begin
  if aRoot <> nil then
    begin
      CurrIdx := TUtil.GetNodeSize(aRoot^.Left);
      if CurrIdx < aIdx then
        begin
          L := aRoot;
          SplitNode(aIdx - Succ(CurrIdx), L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aIdx, R^.Left, L, R^.Left);
        end;
      UpdateSize(aRoot);
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteImplicitTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateSize(Result);
      end;
end;

class procedure TGLiteImplicitTreap.DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T);
var
  LSize: SizeInt;
  Found: PNode;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          aValue := Found^.Value;
          TUtil.FreeNode(Found);
        end
      else
        begin
          if LSize > aIndex then
            DeleteNode(aIndex, aRoot^.Left, aValue)
          else
            DeleteNode(aIndex - Succ(LSize), aRoot^.Right, aValue);
          UpdateSize(aRoot);
        end;
    end;
end;

class operator TGLiteImplicitTreap.Initialize(var aTreap: TGLiteImplicitTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteImplicitTreap.Finalize(var aTreap: TGLiteImplicitTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteImplicitTreap.Copy(constref aSrc: TGLiteImplicitTreap; var aDst: TGLiteImplicitTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteImplicitTreap.AddRef(var aTreap: TGLiteImplicitTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteImplicitTreap.Split(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap;
  out L, R: TGLiteImplicitTreap);
begin
  aTreap.CheckIndexRange(aIndex);
  SplitNode(aIndex, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteImplicitTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteImplicitTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteImplicitTreap.ToArray: TArray;
var
  a: TArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := aNode^.Value;
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot = nil then exit(nil);
  System.SetLength(a, FRoot^.Size);
  Visit(FRoot);
  Result := a;
end;

function TGLiteImplicitTreap.Add(const aValue: T): SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
  if FRoot <> nil then
    FRoot := MergeNode(FRoot, NewNode(aValue))
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitTreap.Insert(aIndex: SizeInt; const aValue: T);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, NewNode(aValue)), R);
        end
      else
        FRoot := MergeNode(FRoot, NewNode(aValue))
    else
      FRoot := MergeNode(NewNode(aValue), FRoot)
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitTreap.Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if aTreap.FRoot = nil then
    exit;
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, aTreap.FRoot), R);
        end
      else
        FRoot := MergeNode(FRoot, aTreap.FRoot)
    else
      FRoot := MergeNode(aTreap.FRoot, FRoot)
  else
    FRoot := aTreap.FRoot;
  aTreap.FRoot := nil;
end;

function TGLiteImplicitTreap.Delete(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  DeleteNode(aIndex, FRoot, Result);
end;

procedure TGLiteImplicitTreap.Split(aIndex: SizeInt; out aTreap: TGLiteImplicitTreap);
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, FRoot, aTreap.FRoot);
end;

procedure TGLiteImplicitTreap.Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitTreap);
var
  L, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  if aCount < FRoot^.Size then
    begin
      SplitNode(aIndex, FRoot, L, R);
      SplitNode(aCount, R, aTreap.FRoot, R);
      FRoot := MergeNode(L, R);
    end
  else
    begin
      aTreap.FRoot := FRoot;
      FRoot := nil;
    end;
end;

procedure TGLiteImplicitTreap.Merge(var aTreap: TGLiteImplicitTreap);
begin
  FRoot := MergeNode(FRoot, aTreap.FRoot);
  aTreap.FRoot := nil;
end;

procedure TGLiteImplicitTreap.RotateLeft(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplicitTreap.RotateRight(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(cnt - aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

{ TGLiteImplSegmentTreap }

function TGLiteImplSegmentTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteImplSegmentTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

procedure TGLiteImplSegmentTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteImplSegmentTreap.CheckInsertRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) > SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteImplSegmentTreap.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := TUtil.GetByIndex(FRoot, aIndex)^.Value;
end;

procedure TGLiteImplSegmentTreap.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  UpdateValue(aIndex, FRoot, aValue);
end;

class function TGLiteImplSegmentTreap.NewNode(const aValue: T): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Prio := SizeUInt(NextRandomQWord);
  Result^.Size := 1;
  Result^.CacheVal := aValue;
  Result^.Value := aValue;
end;

class function TGLiteImplSegmentTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteImplSegmentTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteImplSegmentTreap.UpdateNode(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      CacheVal := aNode^.Value;
      if Left <> nil then
        begin
          Size += Left^.Size;
          CacheVal := TMonoid.BinOp(CacheVal, Left^.CacheVal);
        end;
      if Right <> nil then
        begin
          Size += Right^.Size;
          CacheVal := TMonoid.BinOp(CacheVal, Right^.CacheVal);
        end;
    end;
end;

class procedure TGLiteImplSegmentTreap.UpdateCache(aNode: PNode);
begin
  with aNode^ do
    begin
      CacheVal := aNode^.Value;
      if Left <> nil then
        CacheVal := TMonoid.BinOp(CacheVal, Left^.CacheVal);
      if Right <> nil then
        CacheVal := TMonoid.BinOp(CacheVal, Right^.CacheVal);
    end;
end;

class procedure TGLiteImplSegmentTreap.UpdateValue(aIndex: SizeInt; aRoot: PNode; const aValue: T);
var
  LSize: SizeInt;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        aRoot^.Value := aValue
      else
        if LSize > aIndex then
          UpdateValue(aIndex, aRoot^.Left, aValue)
        else
          UpdateValue(aIndex - Succ(LSize), aRoot^.Right, aValue);
      UpdateCache(aRoot);
    end;
end;

class procedure TGLiteImplSegmentTreap.SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode);
var
  CurrIdx: SizeInt;
begin
  if aRoot <> nil then
    begin
      CurrIdx := TUtil.GetNodeSize(aRoot^.Left);
      if CurrIdx < aIdx then
        begin
          L := aRoot;
          SplitNode(aIdx - Succ(CurrIdx), L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aIdx, R^.Left, L, R^.Left);
        end;
      UpdateNode(aRoot);
    end
  else
    begin
      L := nil;
      R := nil;
    end;
end;

class function TGLiteImplSegmentTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateNode(Result);
      end;
end;

class procedure TGLiteImplSegmentTreap.DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T);
var
  LSize: SizeInt;
  Found: PNode;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          aValue := Found^.Value;
          TUtil.FreeNode(Found);
        end
      else
        begin
          if LSize > aIndex then
            DeleteNode(aIndex, aRoot^.Left, aValue)
          else
            DeleteNode(aIndex - Succ(LSize), aRoot^.Right, aValue);
          UpdateNode(aRoot);
        end;
    end;
end;

class operator TGLiteImplSegmentTreap.Initialize(var aTreap: TGLiteImplSegmentTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteImplSegmentTreap.Finalize(var aTreap: TGLiteImplSegmentTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteImplSegmentTreap.Copy(constref aSrc: TGLiteImplSegmentTreap; var aDst: TGLiteImplSegmentTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteImplSegmentTreap.AddRef(var aTreap: TGLiteImplSegmentTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteImplSegmentTreap.Split(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap;
  out L, R: TGLiteImplSegmentTreap);
begin
  aTreap.CheckIndexRange(aIndex);
  SplitNode(aIndex, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteImplSegmentTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteImplSegmentTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteImplSegmentTreap.ToArray: TArray;
var
  a: TArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := aNode^.Value;
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteImplSegmentTreap.Add(const aValue: T): SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
  if FRoot <> nil then
    FRoot := MergeNode(FRoot, NewNode(aValue))
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplSegmentTreap.Insert(aIndex: SizeInt; const aValue: T);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, NewNode(aValue)), R);
        end
      else
        FRoot := MergeNode(FRoot, NewNode(aValue))
    else
      FRoot := MergeNode(NewNode(aValue), FRoot)
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplSegmentTreap.Insert(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if aTreap.FRoot = nil then
    exit;
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, aTreap.FRoot), R);
        end
      else
        FRoot := MergeNode(FRoot, aTreap.FRoot)
    else
      FRoot := MergeNode(aTreap.FRoot, FRoot)
  else
    FRoot := aTreap.FRoot;
  aTreap.FRoot := nil;
end;

function TGLiteImplSegmentTreap.Delete(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  DeleteNode(aIndex, FRoot, Result);
end;

procedure TGLiteImplSegmentTreap.Split(aIndex: SizeInt; out aTreap: TGLiteImplSegmentTreap);
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, FRoot, aTreap.FRoot);
end;

procedure TGLiteImplSegmentTreap.Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplSegmentTreap);
var
  L, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  if aCount < FRoot^.Size then
    begin
      SplitNode(aIndex, FRoot, L, R);
      SplitNode(aCount, R, aTreap.FRoot, R);
      FRoot := MergeNode(L, R);
    end
  else
    begin
      aTreap.FRoot := FRoot;
      FRoot := nil;
    end;
end;

procedure TGLiteImplSegmentTreap.Merge(var aTreap: TGLiteImplSegmentTreap);
begin
  FRoot := MergeNode(FRoot, aTreap.FRoot);
  aTreap.FRoot := nil;
end;

procedure TGLiteImplSegmentTreap.RotateLeft(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then
    exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplSegmentTreap.RotateRight(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then
    exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(cnt - aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

function TGLiteImplSegmentTreap.RangeQuery(L, R: SizeInt): TResult;
var
  pL, pM, pR: PNode;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    if R < Pred(FRoot^.Size) then
      begin
        SplitNode(L, FRoot, pL, pR);
        SplitNode(Succ(R) - L, pR, pM, pR);
        if pM <> nil then
           Result := pM^.CacheVal
        else
          Result := TMonoid.Identity;
        FRoot := MergeNode(MergeNode(pL, pM), pR);
      end
    else
       Result := TailQuery(L)
  else
    Result := TMonoid.Identity;
end;

function TGLiteImplSegmentTreap.HeadQuery(aIndex: SizeInt): TResult;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  if aIndex < Pred(FRoot^.Size) then
    begin
      SplitNode(Succ(aIndex), FRoot, pL, pR);
      if pL <> nil then
        Result := pL^.CacheVal
      else
        Result := TMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := FRoot^.CacheVal;
end;

function TGLiteImplSegmentTreap.TailQuery(aIndex: SizeInt): TResult;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  if aIndex > 0 then
    begin
      SplitNode(aIndex, FRoot, pL, pR);
      if pR <> nil then
        Result := pR^.CacheVal
      else
        Result := TMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := FRoot^.CacheVal;
end;

{ TGLiteImplicitSegTreap.TNode }

function TGLiteImplicitSegTreap.TNode.GetReversed: Boolean;
begin
  Result := FSize and REV_FLAG <> 0;
end;

function TGLiteImplicitSegTreap.TNode.GetSize: SizeInt;
begin
  Result := FSize and SIZE_MASK;
end;

procedure TGLiteImplicitSegTreap.TNode.SetReversed(aValue: Boolean);
begin
  if aValue then
    FSize := FSize or REV_FLAG
  else
    FSize := FSize and SIZE_MASK
end;

procedure TGLiteImplicitSegTreap.TNode.SetSize(aValue: SizeInt);
begin
  FSize := FSize and REV_FLAG or aValue;
end;

{ TGLiteImplicitSegTreap }

function TGLiteImplicitSegTreap.GetCount: SizeInt;
begin
  Result := specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetNodeSize(FRoot);
end;

function TGLiteImplicitSegTreap.GetHeight: SizeInt;
begin
  Result := specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetHeight(FRoot);
end;

procedure TGLiteImplicitSegTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >=
     SizeUInt(specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteImplicitSegTreap.CheckInsertRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >
     SizeUInt(specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteImplicitSegTreap.GetItem(aIndex: SizeInt): T;
var
  L, M, R: PNode;
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, L, R);
  SplitNode(1, R, M, R);
  Result := M^.Value;
  FRoot := MergeNode(MergeNode(L, M), R);
end;

procedure TGLiteImplicitSegTreap.SetItem(aIndex: SizeInt; const aValue: T);
var
  L, M, R: PNode;
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, L, R);
  SplitNode(1, R, M, R);
  M^.Value := aValue;
  FRoot := MergeNode(MergeNode(L, M), R);
end;

class function TGLiteImplicitSegTreap.NewNode(const aValue: T): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FSize := 1;
  Result^.Prio := SizeUInt(NextRandomQWord);
  Result^.AddVal := TMonoid.ZeroConst;
  Result^.CacheVal := aValue;
  Result^.Value := aValue;
end;

class function TGLiteImplicitSegTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteImplicitSegTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteImplicitSegTreap.UpdateNode(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      CacheVal := aNode^.Value;
      if Left <> nil then
        begin
          Size := Size + Left^.Size;
          if TMonoid.IsZeroConst(Left^.AddVal) then
            CacheVal := TMonoid.BinOp(CacheVal, Left^.CacheVal)
          else
            CacheVal := TMonoid.BinOp(CacheVal,
                        TMonoid.AddConst(Left^.CacheVal, Left^.AddVal, Left^.Size));
        end;
      if Right <> nil then
        begin
          Size := Size + Right^.Size;
          if TMonoid.IsZeroConst(Right^.AddVal) then
            CacheVal := TMonoid.BinOp(CacheVal, Right^.CacheVal)
          else
            CacheVal := TMonoid.BinOp(CacheVal,
                        TMonoid.AddConst(Right^.CacheVal, Right^.AddVal, Right^.Size));
        end;
    end;
end;

class procedure TGLiteImplicitSegTreap.Push(aNode: PNode);
var
  Tmp: PNode;
begin
  with aNode^ do
    begin
      if Reversed then
        begin
          Tmp := Left;
          Left := Right;
          Right := Tmp;
          if Left <> nil then
            Left^.Reversed := Left^.Reversed xor True;
          if Right <> nil then
            Right^.Reversed := Right^.Reversed xor True;
          Reversed := False;
        end;
      if not TMonoid.IsZeroConst(AddVal) then
        begin
          Value := TMonoid.AddConst(Value, AddVal);
          CacheVal := TMonoid.AddConst(CacheVal, AddVal, Size);
          if Left <> nil then
            Left^.AddVal := TMonoid.AddConst(Left^.AddVal, AddVal);
          if Right <> nil then
            Right^.AddVal := TMonoid.AddConst(Right^.AddVal, AddVal);
          AddVal := TMonoid.ZeroConst;
        end;
    end;
end;

class procedure TGLiteImplicitSegTreap.SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode);
var
  CurrIdx: SizeInt;
begin
  if aRoot <> nil then
    begin
      Push(aRoot);
      CurrIdx := specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetNodeSize(aRoot^.Left);
      if CurrIdx < aIdx then
        begin
          L := aRoot;
          SplitNode(aIdx - Succ(CurrIdx), L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aIdx, R^.Left, L, R^.Left);
        end;
      UpdateNode(aRoot);
    end
  else
    begin
      L := nil;
      R := nil;
    end;
end;

class function TGLiteImplicitSegTreap.MergeNode(L, R: PNode): PNode;
begin
  if L <> nil then
    Push(L);
  if R <> nil then
    Push(R);
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateNode(Result);
      end;
end;

class operator TGLiteImplicitSegTreap.Initialize(var aTreap: TGLiteImplicitSegTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteImplicitSegTreap.Finalize(var aTreap: TGLiteImplicitSegTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteImplicitSegTreap.Copy(constref aSrc: TGLiteImplicitSegTreap; var aDst: TGLiteImplicitSegTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteImplicitSegTreap.AddRef(var aTreap: TGLiteImplicitSegTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteImplicitSegTreap.Split(aIndex: SizeInt; var aTreap: TGLiteImplicitSegTreap;
  out L, R: TGLiteImplicitSegTreap);
begin
  aTreap.CheckIndexRange(aIndex);
  SplitNode(aIndex, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteImplicitSegTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteImplicitSegTreap.Clear;
begin
  if FRoot <> nil then
    specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteImplicitSegTreap.ToArray: TArray;
var
  a: TArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := aNode^.Value;
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteImplicitSegTreap.Add(const aValue: T): SizeInt;
begin
  Result := specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.GetNodeSize(FRoot);
  if FRoot <> nil then
    FRoot := MergeNode(FRoot, NewNode(aValue))
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitSegTreap.Insert(aIndex: SizeInt; const aValue: T);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if FRoot <> nil then
    begin
      SplitNode(aIndex, FRoot, L, R);
      FRoot := MergeNode(MergeNode(L, NewNode(aValue)), R);
    end
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitSegTreap.Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitSegTreap);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if aTreap.FRoot = nil then
    exit;
  if FRoot <> nil then
    begin
      SplitNode(aIndex, FRoot, L, R);
      FRoot := MergeNode(MergeNode(L, aTreap.FRoot), R);
    end
  else
    FRoot := aTreap.FRoot;
  aTreap.FRoot := nil;
end;

function TGLiteImplicitSegTreap.Delete(aIndex: SizeInt): T;
var
  L, M, R: PNode;
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, L, R);
  SplitNode(1, R, M, R);
  Result := M^.Value;
  specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.FreeNode(M);
  FRoot := MergeNode(L, R);
end;

function TGLiteImplicitSegTreap.Delete(aIndex, aCount: SizeInt): SizeInt;
var
  L, M, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit(0);
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  SplitNode(aIndex, FRoot, L, R);
  SplitNode(aCount, R, M, R);
  Result := M^.Size;
  specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>.ClearTree(M);
  FRoot := MergeNode(L, R);
end;

procedure TGLiteImplicitSegTreap.Split(aIndex: SizeInt; out aTreap: TGLiteImplicitSegTreap);
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, FRoot, aTreap.FRoot);
end;

procedure TGLiteImplicitSegTreap.Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitSegTreap);
var
  L, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  SplitNode(aIndex, FRoot, L, R);
  SplitNode(aCount, R, aTreap.FRoot, R);
  FRoot := MergeNode(L, R);
end;

procedure TGLiteImplicitSegTreap.Merge(var aTreap: TGLiteImplicitSegTreap);
begin
  FRoot := MergeNode(FRoot, aTreap.FRoot);
  aTreap.FRoot := nil;
end;

procedure TGLiteImplicitSegTreap.RotateLeft(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplicitSegTreap.RotateRight(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(cnt - aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplicitSegTreap.Reverse;
begin
  if FRoot <> nil then
    Reverse(0, FRoot^.Size);
end;

procedure TGLiteImplicitSegTreap.Reverse(aFrom, aCount: SizeInt);
var
  L, M, R: PNode;
begin
  CheckIndexRange(aFrom);
  if aCount < 2 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aFrom);
  SplitNode(aFrom, FRoot, L, R);
  SplitNode(aCount, R, M, R);
  M^.Reversed := True;
  FRoot := MergeNode(MergeNode(L, M), R);
end;

procedure TGLiteImplicitSegTreap.RangeUpdate(L, R: SizeInt; const aConst: T);
var
  pL, pM, pR: PNode;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    begin
      SplitNode(L, FRoot, pL, pR);
      SplitNode(Succ(R) - L, pR, pM, pR);
      if pM <> nil then
         pM^.AddVal := TMonoid.AddConst(pM^.AddVal, aConst, 1);
      FRoot := MergeNode(MergeNode(pL, pM), pR);
    end;
end;

function TGLiteImplicitSegTreap.RangeQuery(L, R: SizeInt): T;
var
  pL, pM, pR: PNode;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    begin
      SplitNode(L, FRoot, pL, pR);
      SplitNode(Succ(R) - L, pR, pM, pR);
      if pM <> nil then
         Result := pM^.CacheVal
      else
        Result := TMonoid.Identity;
      FRoot := MergeNode(MergeNode(pL, pM), pR);
    end
  else
    Result := TMonoid.Identity;
end;

function TGLiteImplicitSegTreap.HeadQuery(aIndex: SizeInt): T;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  SplitNode(Succ(aIndex), FRoot, pL, pR);
  if pL <> nil then
    Result := pL^.CacheVal
  else
    Result := TMonoid.Identity;
  FRoot := MergeNode(pL, pR);
end;

function TGLiteImplicitSegTreap.TailQuery(aIndex: SizeInt): T;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, pL, pR);
  if pR <> nil then
    Result := pR^.CacheVal
  else
    Result := TMonoid.Identity;
  FRoot := MergeNode(pL, pR);
end;

end.
