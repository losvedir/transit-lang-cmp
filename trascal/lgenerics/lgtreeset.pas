{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic sorted set implementations on the top of AVL tree.              *
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
unit lgTreeSet;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgAbstractContainer,
  lgAvlTree;

type

  { TGAbstractTreeSet: common abstract ancestor set class }
  generic TGAbstractTreeSet<T> = class abstract(specialize TGAbstractSet<T>)
  public
  type
    TAbstractTreeSet = specialize TGAbstractTreeSet<T>;

  protected
  type
    TTree = specialize TGCustomAvlTree<T, TEntry>;
    PNode = TTree.PNode;

    TEnumerator = class(TContainerEnumerator)
    protected
      FEnum: TTree.TEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(aSet: TAbstractTreeSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(aSet: TAbstractTreeSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TTailEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(const aLowBound: T; aSet: TAbstractTreeSet; aInclusive: Boolean);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FTree: TTree;
    function  GetCount: SizeInt; override;
    function  GetCapacity: SizeInt; override;
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoClear; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    function  DoAdd(const aValue: T): Boolean; override;
    function  DoExtract(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
    function  DoExtractIf(aTest: TTest): TArray; override;
    function  DoExtractIf(aTest: TOnTest): TArray; override;
    function  DoExtractIf(aTest: TNestTest): TArray; override;
    function  FindNearestLT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestLE(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGE(const aPattern: T; out aValue: T): Boolean;
  public
    destructor Destroy; override;
    function Reverse: IEnumerable; override;
    function Contains(const aValue: T): Boolean; override;
    function FindMin(out aValue: T): Boolean;
    function FindMax(out aValue: T): Boolean;
  { returns True if exists element whose value greater then or equal to aValue (depending on aInclusive) }
    function FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean = True): Boolean;
  { returns True if exists element whose value less then aValue (or equal to aValue, depending on aInclusive) }
    function FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean = False): Boolean;
  { enumerates values whose are strictly less than(if not aInclusive) aHighBound }
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; virtual; abstract;
  { enumerates values whose are greater than or equal to(if aInclusive) aLowBound }
    function Tail(const aLowBound: T; aInclusive: Boolean = True): IEnumerable;
  { enumerates values whose are greater than or equal to aLowBound and strictly less than aHighBound(by default)}
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
       virtual; abstract;
  { returns sorted set whose items are strictly less than(if not aInclusive) aHighBound }
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TAbstractTreeSet; virtual; abstract;
  { returns sorted set whose items are greater than or equal(if aInclusive) to aLowBound}
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TAbstractTreeSet; virtual; abstract;
  { returns sorted set whose items are greater than or equal to aLowBound and strictly less than
    aHighBound(by default) }
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TAbstractTreeSet;
       virtual; abstract;
  end;

  { TGBaseTreeSet implements sorted set;
      functor TCmpRel (comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseTreeSet<T, TCmpRel> = class(specialize TGAbstractTreeSet<T>)
  protected
  type
    TBaseTree = specialize TGAvlTree<T, TEntry, TCmpRel>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; aSet: TAbstractTreeSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet; aBounds: TRangeBounds); overload;
    end;

    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor CreateCopy(aSet: TGBaseTreeSet);
    function Clone: TGBaseTreeSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGBaseTreeSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGBaseTreeSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGBaseTreeSet;
      override;
  end;

  { TGTreeSet implements sorded set, it assumes that type T implements TCmpRel }
  generic TGTreeSet<T> = class(specialize TGBaseTreeSet<T, T>);

  { TGComparableTreeSet implements sorted set; it assumes that type T has defined comparison operator < }
  generic TGComparableTreeSet<T> = class(specialize TGAbstractTreeSet<T>)
  protected
  type
    TComparableTree = specialize TGComparableAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    private
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FInclusive,
      FDone: Boolean;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; aSet: TAbstractTreeSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet; aBounds: TRangeBounds); overload;
    end;

    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor CreateCopy(aSet: TGComparableTreeSet);
    function Clone: TGComparableTreeSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGComparableTreeSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGComparableTreeSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGComparableTreeSet;
      override;
  end;

  generic TGObjectTreeSet<T: class; TCmpRel> = class(specialize TGBaseTreeSet<T, TCmpRel>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure NodeRemoved(p: PEntry);
    procedure DoClear; override;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aSet: TGObjectTreeSet);
    function  Clone: TGObjectTreeSet; override;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  { TGObjTreeSet assumes that type T implements TCmpRel}
  generic TGObjTreeSet<T: class> = class(specialize TGObjectTreeSet<T, T>);

  { TGRegularTreeSet implements sorted set with regular comparator }
  generic TGRegularTreeSet<T> = class(specialize TGAbstractTreeSet<T>)
  protected
  type
    TRegularTree = specialize TGRegularAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    private
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FLess: TLess;
      FInclusive,
      FDone: Boolean;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; aSet: TAbstractTreeSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet; aBounds: TRangeBounds); overload;
    end;

  public
    constructor Create;
    constructor Create(aLess: TLess);
    constructor Create(aCapacity: SizeInt; aLess: TLess);
    constructor Create(const a: array of T; aLess: TLess);
    constructor Create(e: IEnumerable; aLess: TLess);
    constructor CreateCopy(aSet: TGRegularTreeSet);
    function Comparator: TLess; inline;
    function Clone: TGRegularTreeSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGRegularTreeSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGRegularTreeSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGRegularTreeSet;
      override;
  end;

  { TGObjectRegularTreeSet }
  generic TGObjectRegularTreeSet<T: class> = class(specialize TGRegularTreeSet<T>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure NodeRemoved(p: PEntry);
    procedure DoClear; override;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aLess: TLess; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLess: TLess; aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aLess: TLess; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aLess: TLess; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aSet: TGObjectRegularTreeSet);
    function  Clone: TGObjectRegularTreeSet; override;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  { TGDelegatedTreeSet implements sorted set with delegated comparator }
  generic TGDelegatedTreeSet<T> = class(specialize TGAbstractTreeSet<T>)
  protected
  type
    TDelegatedTree = specialize TGDelegatedAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FLess: TOnLess;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; aSet: TAbstractTreeSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet; aBounds: TRangeBounds); overload;
    end;

  public
    constructor Create;
    constructor Create(aLess: TOnLess);
    constructor Create(aCapacity: SizeInt; aLess: TOnLess);
    constructor Create(const a: array of T; aLess: TOnLess);
    constructor Create(e: IEnumerable; aLess: TOnLess);
    constructor CreateCopy(aSet: TGDelegatedTreeSet);
    function Comparator: TOnLess; inline;
    function Clone: TGDelegatedTreeSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGDelegatedTreeSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGDelegatedTreeSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGDelegatedTreeSet;
      override;
  end;

  generic TGObjectDelegatedTreeSet<T: class> = class(specialize TGDelegatedTreeSet<T>)
  protected
    FOwnsObjects: Boolean;
    procedure NodeRemoved(p: PEntry);
    procedure DoClear; override;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aLess: TOnLess; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLess: TOnLess; aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aLess: TOnLess; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aLess: TOnLess; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aSet: TGObjectDelegatedTreeSet);
    function  Clone: TGObjectDelegatedTreeSet; override;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  { TGLiteTreeSet implements sorted set;
      functor TCmpRel (comparision relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGLiteTreeSet<T, TCmpRel> = record
  private
  type
    TEntry = record
      Key: T;
    end;
    PEntry = ^TEntry;
    PSet   = ^TGLiteTreeSet;

    TTree = specialize TGLiteAvlTree<T, TEntry, TCmpRel>;
    PTree = ^TTree;

  public
  type
    IEnumerable = specialize IGEnumerable<T>;
    ICollection = specialize IGCollection<T>;
    TTest       = specialize TGTest<T>;
    TOnTest     = specialize TGOnTest<T>;
    TNestTest   = specialize TGNestTest<T>;
    TArray      = array of T;

    TEnumerator = record
    private
      FEnum: TTree.TEnumerator;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aSet: TGLiteTreeSet);
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FTree: PTree;
      FNodeList: TTree.TNodeList;
      FCurrNode,
      FFirstNode: SizeInt;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aSet: TGLiteTreeSet);
      function  MoveNext: Boolean; inline;
      procedure Reset;
      property  Current: T read GetCurrent;
    end;

    THeadEnumerator = record
    private
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aSet: TGLiteTreeSet; const aHighBound: T; aInclusive: Boolean);
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TTailEnumerator = record
    private
      FTree: PTree;
      FNodeList: TTree.TNodeList;
      FCurrNode,
      FFirstNode: SizeInt;
      FInCycle: Boolean;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aSet: TGLiteTreeSet; const aLowBound: T; aInclusive: Boolean);
      function  MoveNext: Boolean; inline;
      procedure Reset;
      property  Current: T read GetCurrent;
    end;

    TRangeEnumerator = record
    private
      FEnum: TTailEnumerator;
      FHighBound: T;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aSet: TGLiteTreeSet; const aLowBound, aHighBound: T; aBounds: TRangeBounds);
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FSet: PSet;
    public
      constructor Create(aSet: PSet);
      function GetEnumerator: TReverseEnumerator;
    end;

    THead = record
    private
      FSet: PSet;
      FHighBound: T;
      FInclusive: Boolean;
    public
      constructor Create(aSet: PSet; const aHighBound: T; aInclusive: Boolean);
      function GetEnumerator: THeadEnumerator;
    end;

    TTail = record
    private
      FSet: PSet;
      FLowBound: T;
      FInclusive: Boolean;
    public
      constructor Create(aSet: PSet; const aLowBound: T; aInclusive: Boolean);
      function GetEnumerator: TTailEnumerator;
    end;

    TRange = record
    private
      FSet: PSet;
      FLowBound,
      FHighBound: T;
      FBounds: TRangeBounds;
    public
      constructor Create(aSet: PSet; const aLowBound, aHighBound: T; aBounds: TRangeBounds);
      function GetEnumerator: TRangeEnumerator;
    end;

  private
    FTree: TTree;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    function  FindNearestLT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestLE(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGE(const aPattern: T; out aValue: T): Boolean;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  GetHeadEnumerator(const aHighBound: T; aInclusive: Boolean): THeadEnumerator;
    function  GetTailEnumerator(const aLowBound: T; aInclusive: Boolean): TTailEnumerator;
    function  GetRangeEnumerator(const aLowBound, aHighBound: T; aBounds: TRangeBounds): TRangeEnumerator;
  public
    function  GetEnumerator: TEnumerator;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear; inline;
    procedure TrimToFit; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
  { returns True if element added }
    function  Add(const aValue: T): Boolean;
  { returns count of added elements }
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
    function  AddAll(constref aSet: TGLiteTreeSet): SizeInt;
    function  Contains(const aValue: T): Boolean; inline;
    function  NonContains(const aValue: T): Boolean;
    function  ContainsAny(const a: array of T): Boolean;
    function  ContainsAny(e: IEnumerable): Boolean;
    function  ContainsAny(constref aSet: TGLiteTreeSet): Boolean;
    function  ContainsAll(const a: array of T): Boolean;
    function  ContainsAll(e: IEnumerable): Boolean;
    function  ContainsAll(constref aSet: TGLiteTreeSet): Boolean;
  { returns True if element removed }
    function  Remove(const aValue: T): Boolean; inline;
  { returns count of removed elements }
    function  RemoveAll(const a: array of T): SizeInt;
    function  RemoveAll(e: IEnumerable): SizeInt;
    function  RemoveAll(constref aSet: TGLiteTreeSet): SizeInt;
  { returns count of removed elements }
    function  RemoveIf(aTest: TTest): SizeInt;
    function  RemoveIf(aTest: TOnTest): SizeInt;
    function  RemoveIf(aTest: TNestTest): SizeInt;
  { returns True if element extracted }
    function  Extract(const aValue: T): Boolean; inline;
    function  ExtractIf(aTest: TTest): TArray;
    function  ExtractIf(aTest: TOnTest): TArray;
    function  ExtractIf(aTest: TNestTest): TArray;
  { will contain only those elements that are simultaneously contained in self and aCollection/aSet }
    procedure RetainAll(aCollection: ICollection);
    procedure RetainAll(constref aSet: TGLiteTreeSet);
    function  IsSuperset(constref aSet: TGLiteTreeSet): Boolean;
    function  IsSubset(constref aSet: TGLiteTreeSet): Boolean;
    function  IsEqual(constref aSet: TGLiteTreeSet): Boolean;
    function  Intersecting(constref aSet: TGLiteTreeSet): Boolean;
    procedure Intersect(constref aSet: TGLiteTreeSet);
    procedure Join(constref aSet: TGLiteTreeSet);
    procedure Subtract(constref aSet: TGLiteTreeSet);
    procedure SymmetricSubtract(constref aSet: TGLiteTreeSet);
    function  FindMin(out aValue: T): Boolean;
    function  FindMax(out aValue: T): Boolean;
  { returns True if exists element whose value greater then or equal to aValue (depending on aInclusive) }
    function  FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean = True): Boolean; inline;
  { returns True if exists element whose value less then aValue (or equal to aValue, depending on aInclusive) }
    function  FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean = False): Boolean; inline;
  { enumerates values whose are strictly less than(if not aInclusive) aHighBound }
    function  Head(const aHighBound: T; aInclusive: Boolean = False): THead; inline;
  { enumerates values whose are greater than or equal to(if aInclusive) aLowBound }
    function  Tail(const aLowBound: T; aInclusive: Boolean = True): TTail; inline;
  { enumerates values whose are greater than or equal to aLowBound and strictly less than aHighBound(by default)}
    function  Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TRange; inline;
  { returns sorted set whose items are strictly less than(if not aInclusive) aHighBound }
    function  HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGLiteTreeSet;
  { returns sorted set whose items are greater than or equal(if aInclusive) to aLowBound}
    function  TailSet(const aLowBound: T; aInclusive: Boolean = True): TGLiteTreeSet;
  { returns sorted set whose items are greater than or equal to aLowBound and strictly less than
    aHighBound(by default) }
    function  SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGLiteTreeSet;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    class operator +(constref L, R: TGLiteTreeSet): TGLiteTreeSet;
    class operator -(constref L, R: TGLiteTreeSet): TGLiteTreeSet;
    class operator *(constref L, R: TGLiteTreeSet): TGLiteTreeSet;
    class operator ><(constref L, R: TGLiteTreeSet): TGLiteTreeSet;
    class operator =(constref L, R: TGLiteTreeSet): Boolean; inline;
    class operator <=(constref L, R: TGLiteTreeSet): Boolean; inline;
    class operator in(constref aValue: T; const aSet: TGLiteTreeSet): Boolean; inline;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGAbstractTreeSet.TEnumerator }

function TGAbstractTreeSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeSet.TEnumerator.Create(aSet: TAbstractTreeSet);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumerator;
end;

destructor TGAbstractTreeSet.TEnumerator.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractTreeSet.TEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractTreeSet.TReverseEnumerable }

function TGAbstractTreeSet.TReverseEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeSet.TReverseEnumerable.Create(aSet: TAbstractTreeSet);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetReverseEnumerator;
end;

destructor TGAbstractTreeSet.TReverseEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeSet.TReverseEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractTreeSet.TReverseEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractTreeSet.TTailEnumerable }

function TGAbstractTreeSet.TTailEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeSet.TTailEnumerable.Create(const aLowBound: T; aSet: TAbstractTreeSet;
  aInclusive: Boolean);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumeratorAt(aLowBound, aInclusive);
end;

destructor TGAbstractTreeSet.TTailEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeSet.TTailEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractTreeSet.TTailEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractTreeSet }

function TGAbstractTreeSet.GetCount: SizeInt;
begin
  Result := FTree.Count;
end;

function TGAbstractTreeSet.GetCapacity: SizeInt;
begin
  Result := FTree.Capacity;
end;

function TGAbstractTreeSet.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGAbstractTreeSet.DoClear;
begin
  FTree.Clear;
end;

procedure TGAbstractTreeSet.DoTrimToFit;
begin
  FTree.TrimToFit;
end;

procedure TGAbstractTreeSet.DoEnsureCapacity(aValue: SizeInt);
begin
  FTree.EnsureCapacity(aValue);
end;

function TGAbstractTreeSet.DoAdd(const aValue: T): Boolean;
var
  p: PNode;
begin
  Result := not FTree.FindOrAdd(aValue, p);
end;

function TGAbstractTreeSet.DoExtract(const aValue: T): Boolean;
begin
  Result := FTree.Remove(aValue);
end;

function TGAbstractTreeSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := FTree.RemoveIf(aTest);
end;

function TGAbstractTreeSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := FTree.RemoveIf(aTest);
end;

function TGAbstractTreeSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := FTree.RemoveIf(aTest);
end;

function TGAbstractTreeSet.DoExtractIf(aTest: TTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

function TGAbstractTreeSet.DoExtractIf(aTest: TOnTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

function TGAbstractTreeSet.DoExtractIf(aTest: TNestTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

function TGAbstractTreeSet.FindNearestLT(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindLess(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeSet.FindNearestLE(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindLessOrEqual(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeSet.FindNearestGT(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindGreater(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeSet.FindNearestGE(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindGreaterOrEqual(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

destructor TGAbstractTreeSet.Destroy;
begin
  DoClear;
  FTree.Free;
  inherited;
end;

function TGAbstractTreeSet.Reverse: IEnumerable;
begin
  BeginIteration;
  Result := TReverseEnumerable.Create(Self);
end;

function TGAbstractTreeSet.Contains(const aValue: T): Boolean;
begin
  Result := FTree.Find(aValue) <> nil;
end;

function TGAbstractTreeSet.FindMin(out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.Lowest;
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeSet.FindMax(out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.Highest;
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeSet.FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestGE(aValue, aCeil)
  else
    Result := FindNearestGT(aValue, aCeil);
end;

function TGAbstractTreeSet.FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestLE(aValue, aFloor)
  else
    Result := FindNearestLT(aValue, aFloor);
end;

function TGAbstractTreeSet.Tail(const aLowBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := TTailEnumerable.Create(aLowBound, Self, aInclusive);
end;

{ TGBaseTreeSet.THeadEnumerable }

function TGBaseTreeSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGBaseTreeSet.THeadEnumerable.Create(const aHighBound: T; aSet: TAbstractTreeSet;
  aInclusive: Boolean);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumerator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGBaseTreeSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGBaseTreeSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not TCmpRel.Less(FHighBound, FEnum.Current^.Data.Key)
  else
    Result := TCmpRel.Less(FEnum.Current^.Data.Key, FHighBound);
  FDone := not Result;
end;

procedure TGBaseTreeSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGBaseTreeSet.TRangeEnumerable }

constructor TGBaseTreeSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet;
  aBounds: TRangeBounds);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGBaseTreeSet }

class function TGBaseTreeSet.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

class function TGBaseTreeSet.Comparator: TLess;
begin
  Result := @DoCompare;
end;

constructor TGBaseTreeSet.Create;
begin
  FTree := TBaseTree.Create;
end;

constructor TGBaseTreeSet.Create(aCapacity: SizeInt);
begin
  FTree := TBaseTree.Create(aCapacity);
end;

constructor TGBaseTreeSet.Create(const a: array of T);
begin
  FTree := TBaseTree.Create;
  DoAddAll(a);
end;

constructor TGBaseTreeSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TGBaseTreeSet then
    CreateCopy(TGBaseTreeSet(o))
  else
    begin
      if o is TSpecSet then
        Create(TSpecSet(o).Count)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGBaseTreeSet.CreateCopy(aSet: TGBaseTreeSet);
begin
  FTree := TBaseTree(aSet.FTree).Clone;
end;

function TGBaseTreeSet.Clone: TGBaseTreeSet;
begin
  Result := TGBaseTreeSet.CreateCopy(Self);
end;

function TGBaseTreeSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGBaseTreeSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGBaseTreeSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGBaseTreeSet;
var
  v: T;
begin
  Result := TGBaseTreeSet.Create;
  for v in Head(aHighBound, aInclusive) do
    Result.Add(v);
end;

function TGBaseTreeSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGBaseTreeSet;
var
  v: T;
begin
  Result := TGBaseTreeSet.Create;
  for v in Tail(aLowBound, aInclusive) do
    Result.Add(v);
end;

function TGBaseTreeSet.SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TGBaseTreeSet;
var
  v: T;
begin
    Result := TGBaseTreeSet.Create;
  for v in Range(aLowBound, aHighBound, aIncludeBounds) do
    Result.Add(v);
end;

{ TGComparableTreeSet.THeadEnumerable }

function TGComparableTreeSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGComparableTreeSet.THeadEnumerable.Create(const aHighBound: T; aSet: TAbstractTreeSet;
  aInclusive: Boolean);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumerator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGComparableTreeSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGComparableTreeSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not(FHighBound < FEnum.Current^.Data.Key)
  else
    Result := FEnum.Current^.Data.Key < FHighBound;
  FDone := not Result;
end;

procedure TGComparableTreeSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGComparableTreeSet.TRangeEnumerable }

constructor TGComparableTreeSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet;
  aBounds: TRangeBounds);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGComparableTreeSet }

class function TGComparableTreeSet.DoCompare(const L, R: T): Boolean;
begin
  Result := L < R;
end;

class function TGComparableTreeSet.Comparator: TLess;
begin
  Result := @DoCompare;
end;

constructor TGComparableTreeSet.Create;
begin
  FTree := TComparableTree.Create;
end;

constructor TGComparableTreeSet.Create(aCapacity: SizeInt);
begin
  FTree := TComparableTree.Create(aCapacity);
end;

constructor TGComparableTreeSet.Create(const a: array of T);
begin
  FTree := TComparableTree.Create;
  DoAddAll(a);
end;

constructor TGComparableTreeSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TGComparableTreeSet then
    CreateCopy(TGComparableTreeSet(o))
  else
    begin
      if o is TSpecSet then
        Create(TSpecSet(o).Count)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGComparableTreeSet.CreateCopy(aSet: TGComparableTreeSet);
begin
  FTree := TComparableTree(aSet.FTree).Clone;
end;

function TGComparableTreeSet.Clone: TGComparableTreeSet;
begin
  Result := TGComparableTreeSet.CreateCopy(Self);
end;

function TGComparableTreeSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGComparableTreeSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGComparableTreeSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGComparableTreeSet;
var
  v: T;
begin
  Result := TGComparableTreeSet.Create;
  for v in Head(aHighBound, aInclusive) do
    Result.Add(v);
end;

function TGComparableTreeSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGComparableTreeSet;
var
  v: T;
begin
  Result := TGComparableTreeSet.Create;
  for v in Tail(aLowBound, aInclusive) do
    Result.Add(v);
end;

function TGComparableTreeSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGComparableTreeSet;
var
  v: T;
begin
  Result := TGComparableTreeSet.Create;
  for v in Range(aLowBound, aHighBound, aIncludeBounds) do
    Result.Add(v);
end;

{ TGObjectTreeSet }

procedure TGObjectTreeSet.NodeRemoved(p: PEntry);
begin
  p^.Key.Free;
end;

procedure TGObjectTreeSet.DoClear;
var
  p: PNode;
begin
  if OwnsObjects then
    for p in FTree do
      p^.Data.Key.Free;
  inherited;
end;

function TGObjectTreeSet.DoRemove(const aValue: T): Boolean;
begin
  Result := inherited DoRemove(aValue);
  if Result and OwnsObjects then
    aValue.Free;
end;

function TGObjectTreeSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectTreeSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectTreeSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

constructor TGObjectTreeSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeSet.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeSet.Create(const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(a);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeSet.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeSet.CreateCopy(aSet: TGObjectTreeSet);
begin
  FTree := TBaseTree(aSet.FTree).Clone;
  OwnsObjects := aSet.OwnsObjects;
end;

function TGObjectTreeSet.Clone: TGObjectTreeSet;
begin
  Result := TGObjectTreeSet.CreateCopy(Self);
end;

{ TGRegularTreeSet.THeadEnumerable }

function TGRegularTreeSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGRegularTreeSet.THeadEnumerable.Create(const aHighBound: T; aSet: TAbstractTreeSet;
  aInclusive: Boolean);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumerator;
  FLess := TRegularTree(aSet.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGRegularTreeSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGRegularTreeSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not FLess(FHighBound, FEnum.Current^.Data.Key)
  else
    Result := FLess(FEnum.Current^.Data.Key, FHighBound);
  FDone := not Result;
end;

procedure TGRegularTreeSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGRegularTreeSet.TRangeEnumerable }

constructor TGRegularTreeSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet;
  aBounds: TRangeBounds);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FLess := TRegularTree(aSet.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGRegularTreeSet }

constructor TGRegularTreeSet.Create;
begin
  FTree := TRegularTree.Create(TDefaults.Less);
end;

constructor TGRegularTreeSet.Create(aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
end;

constructor TGRegularTreeSet.Create(aCapacity: SizeInt; aLess: TLess);
begin
  FTree := TRegularTree.Create(aCapacity, aLess);
end;

constructor TGRegularTreeSet.Create(const a: array of T; aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
  DoAddAll(a);
end;

constructor TGRegularTreeSet.Create(e: IEnumerable; aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
  DoAddAll(e);
end;

constructor TGRegularTreeSet.CreateCopy(aSet: TGRegularTreeSet);
begin
  FTree := TRegularTree(aSet.FTree).Clone;
end;

function TGRegularTreeSet.Comparator: TLess;
begin
  Result := TRegularTree(FTree).Comparator;
end;

function TGRegularTreeSet.Clone: TGRegularTreeSet;
begin
  Result := TGRegularTreeSet.Create(Self, Comparator);
end;

function TGRegularTreeSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGRegularTreeSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGRegularTreeSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGRegularTreeSet;
var
  v: T;
begin
  Result := TGRegularTreeSet.Create(Comparator);
  for v in Head(aHighBound, aInclusive) do
    Result.Add(v);
end;

function TGRegularTreeSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGRegularTreeSet;
var
  v: T;
begin
  Result := TGRegularTreeSet.Create(Comparator);
  for v in Tail(aLowBound, aInclusive) do
    Result.Add(v);
end;

function TGRegularTreeSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGRegularTreeSet;
var
  v: T;
begin
  Result := TGRegularTreeSet.Create(Comparator);
  for v in Range(aLowBound, aHighBound, aIncludeBounds) do
    Result.Add(v);
end;

{ TGObjectRegularTreeSet }

procedure TGObjectRegularTreeSet.NodeRemoved(p: PEntry);
begin
  p^.Key.Free;
end;

procedure TGObjectRegularTreeSet.DoClear;
var
  p: PNode;
begin
  if OwnsObjects then
    for p in FTree do
      p^.Data.Key.Free;
  inherited;
end;

function TGObjectRegularTreeSet.DoRemove(const aValue: T): Boolean;
begin
  Result := inherited DoRemove(aValue);
  if Result and OwnsObjects then
    aValue.Free;
end;

function TGObjectRegularTreeSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectRegularTreeSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectRegularTreeSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

constructor TGObjectRegularTreeSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectRegularTreeSet.Create(aLess: TLess; aOwnsObjects: Boolean);
begin
  inherited Create(aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectRegularTreeSet.Create(aCapacity: SizeInt; aLess: TLess; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectRegularTreeSet.Create(const a: array of T; aLess: TLess; aOwnsObjects: Boolean);
begin
  inherited Create(a, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectRegularTreeSet.Create(e: IEnumerable; aLess: TLess; aOwnsObjects: Boolean);
begin
  inherited Create(e, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectRegularTreeSet.CreateCopy(aSet: TGObjectRegularTreeSet);
begin
  FTree := TRegularTree(aSet.FTree).Clone;
  FOwnsObjects := aSet.OwnsObjects;
end;

function TGObjectRegularTreeSet.Clone: TGObjectRegularTreeSet;
begin
  Result := TGObjectRegularTreeSet.CreateCopy(Self);
end;

{ TGDelegatedTreeSet.THeadEnumerable }

function TGDelegatedTreeSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGDelegatedTreeSet.THeadEnumerable.Create(const aHighBound: T; aSet: TAbstractTreeSet;
  aInclusive: Boolean);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumerator;
  FLess := TDelegatedTree(aSet.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGDelegatedTreeSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGDelegatedTreeSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not FLess(FHighBound, FEnum.Current^.Data.Key)
  else
    Result := FLess(FEnum.Current^.Data.Key, FHighBound);
  FDone := not Result;
end;

procedure TGDelegatedTreeSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGDelegatedTreeSet.TRangeEnumerable }

constructor TGDelegatedTreeSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T; aSet: TAbstractTreeSet;
  aBounds: TRangeBounds);
begin
  inherited Create(aSet);
  FEnum := aSet.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FLess := TDelegatedTree(aSet.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGDelegatedTreeSet }

constructor TGDelegatedTreeSet.Create;
begin
  FTree := TDelegatedTree.Create(TDefaults.OnLess);
end;

constructor TGDelegatedTreeSet.Create(aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
end;

constructor TGDelegatedTreeSet.Create(aCapacity: SizeInt; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aCapacity, aLess);
end;

constructor TGDelegatedTreeSet.Create(const a: array of T; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
  DoAddAll(a);
end;

constructor TGDelegatedTreeSet.Create(e: IEnumerable; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
  DoAddAll(e);
end;

constructor TGDelegatedTreeSet.CreateCopy(aSet: TGDelegatedTreeSet);
begin
  FTree := TDelegatedTree(aSet.FTree).Clone;
end;

function TGDelegatedTreeSet.Comparator: TOnLess;
begin
  Result := TDelegatedTree(FTree).Comparator;
end;

function TGDelegatedTreeSet.Clone: TGDelegatedTreeSet;
begin
  Result := TGDelegatedTreeSet.CreateCopy(Self);
end;

function TGDelegatedTreeSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGDelegatedTreeSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGDelegatedTreeSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGDelegatedTreeSet;
var
  v: T;
begin
  Result := TGDelegatedTreeSet.Create(Comparator);
  for v in Head(aHighBound, aInclusive) do
    Result.Add(v);
end;

function TGDelegatedTreeSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGDelegatedTreeSet;
var
  v: T;
begin
  Result := TGDelegatedTreeSet.Create(Comparator);
  for v in Tail(aLowBound, aInclusive) do
    Result.Add(v);
end;

function TGDelegatedTreeSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGDelegatedTreeSet;
var
  v: T;
begin
  Result := TGDelegatedTreeSet.Create(Comparator);
  for v in Range(aLowBound, aHighBound, aIncludeBounds) do
    Result.Add(v);
end;

{ TGObjectDelegatedTreeSet }

procedure TGObjectDelegatedTreeSet.NodeRemoved(p: PEntry);
begin
  p^.Key.Free;
end;

procedure TGObjectDelegatedTreeSet.DoClear;
var
  p: PNode;
begin
  if OwnsObjects then
    for p in FTree do
      p^.Data.Key.Free;
  inherited;
end;

function TGObjectDelegatedTreeSet.DoRemove(const aValue: T): Boolean;
begin
  Result := inherited DoRemove(aValue);
  if Result and OwnsObjects then
    aValue.Free;
end;

function TGObjectDelegatedTreeSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectDelegatedTreeSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

function TGObjectDelegatedTreeSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTree.RemoveIf(aTest, @NodeRemoved)
  else
    Result := FTree.RemoveIf(aTest);
end;

constructor TGObjectDelegatedTreeSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectDelegatedTreeSet.Create(aLess: TOnLess; aOwnsObjects: Boolean);
begin
  inherited Create(aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDelegatedTreeSet.Create(aCapacity: SizeInt; aLess: TOnLess; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDelegatedTreeSet.Create(const a: array of T;
  aLess: TOnLess; aOwnsObjects: Boolean);
begin
  inherited Create(a, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDelegatedTreeSet.Create(e: IEnumerable;
  aLess: TOnLess; aOwnsObjects: Boolean);
begin
  inherited Create(e, aLess);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDelegatedTreeSet.CreateCopy(aSet: TGObjectDelegatedTreeSet);
begin
  FTree := TDelegatedTree(aSet.FTree).Clone;
  FOwnsObjects := aSet.OwnsObjects;
end;

function TGObjectDelegatedTreeSet.Clone: TGObjectDelegatedTreeSet;
begin
  Result := TGObjectDelegatedTreeSet.CreateCopy(Self);
end;

{ TGLiteTreeSet.TEnumerator }

function TGLiteTreeSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

constructor TGLiteTreeSet.TEnumerator.Create(const aSet: TGLiteTreeSet);
begin
  FEnum := aSet.FTree.GetEnumerator;
end;

function TGLiteTreeSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGLiteTreeSet.TEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGLiteTreeSet.TReverseEnumerator }

function TGLiteTreeSet.TReverseEnumerator.GetCurrent: T;
begin
  Result := FNodeList[FCurrNode].Data.Key;
end;

constructor TGLiteTreeSet.TReverseEnumerator.Create(const aSet: TGLiteTreeSet);
begin
  FTree := @aSet.FTree;
  FNodeList := FTree^.NodeList;
  FFirstNode := FTree^.Highest;
  FInCycle := False;
  FCurrNode := 0;
end;

function TGLiteTreeSet.TReverseEnumerator.MoveNext: Boolean;
var
  NextNode: SizeInt = 0;
begin
  if FCurrNode <> 0 then
    NextNode := FTree^.Predecessor(FCurrNode)
  else
    if not FInCycle then
      begin
        NextNode := FFirstNode;
        FInCycle := True;
      end;
  Result := NextNode <> 0;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLiteTreeSet.TReverseEnumerator.Reset;
begin
  FInCycle := False;
  FCurrNode := 0;
end;

{ TGLiteTreeSet.THeadEnumerator }

function TGLiteTreeSet.THeadEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

constructor TGLiteTreeSet.THeadEnumerator.Create(const aSet: TGLiteTreeSet; const aHighBound: T;
  aInclusive: Boolean);
begin
  FEnum := aSet.FTree.GetEnumerator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
  FDone := False;
end;

function TGLiteTreeSet.THeadEnumerator.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not TCmpRel.Less(FHighBound, FEnum.Current^.Key)
  else
    Result := TCmpRel.Less(FEnum.Current^.Key, FHighBound);
  FDone := not Result;
end;

procedure TGLiteTreeSet.THeadEnumerator.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGLiteTreeSet.TTailEnumerator }

function TGLiteTreeSet.TTailEnumerator.GetCurrent: T;
begin
  Result := FNodeList[FCurrNode].Data.Key;
end;

constructor TGLiteTreeSet.TTailEnumerator.Create(const aSet: TGLiteTreeSet; const aLowBound: T;
  aInclusive: Boolean);
begin
  FTree := @aSet.FTree;
  FNodeList := FTree^.NodeList;
  if aInclusive then
    FFirstNode := FTree^.FindGreaterOrEqual(aLowBound)
  else
    FFirstNode := FTree^.FindGreater(aLowBound);
  FInCycle := False;
  FCurrNode := 0;
end;

function TGLiteTreeSet.TTailEnumerator.MoveNext: Boolean;
var
  NextNode: SizeInt = 0;
begin
  if FCurrNode <> 0 then
    NextNode := FTree^.Successor(FCurrNode)
  else
    if not FInCycle then
      begin
        NextNode := FFirstNode;
        FInCycle := True;
      end;
  Result := NextNode <> 0;
  if Result then
    FCurrNode := NextNode;
end;

procedure TGLiteTreeSet.TTailEnumerator.Reset;
begin
  FInCycle := False;
  FCurrNode := 0;
end;

{ TGLiteTreeSet.TRangeEnumerator }

function TGLiteTreeSet.TRangeEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current;
end;

constructor TGLiteTreeSet.TRangeEnumerator.Create(const aSet: TGLiteTreeSet; const aLowBound, aHighBound: T;
  aBounds: TRangeBounds);
begin
  FEnum := aSet.GetTailEnumerator(aLowBound, rbLow in aBounds);
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
  FDone := False;
end;

function TGLiteTreeSet.TRangeEnumerator.MoveNext: Boolean;
begin
  if FDone or not FEnum.MoveNext then
    exit(False);
  if FInclusive then
    Result := not TCmpRel.Less(FHighBound, FEnum.Current)
  else
    Result := TCmpRel.Less(FEnum.Current, FHighBound);
  FDone := not Result;
end;

procedure TGLiteTreeSet.TRangeEnumerator.Reset;
begin
  FEnum.Reset;
  FDone := False;
end;

{ TGLiteTreeSet.TReverse }

constructor TGLiteTreeSet.TReverse.Create(aSet: PSet);
begin
  FSet := aSet;
end;

function TGLiteTreeSet.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result := FSet^.GetReverseEnumerator;
end;

{ TGLiteTreeSet.THead }

constructor TGLiteTreeSet.THead.Create(aSet: PSet; const aHighBound: T; aInclusive: Boolean);
begin
  FSet := aSet;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

function TGLiteTreeSet.THead.GetEnumerator: THeadEnumerator;
begin
  Result := FSet^.GetHeadEnumerator(FHighBound, FInclusive);
end;

{ TGLiteTreeSet.TTail }

constructor TGLiteTreeSet.TTail.Create(aSet: PSet; const aLowBound: T; aInclusive: Boolean);
begin
  FSet := aSet;
  FLowBound := aLowBound;
  FInclusive := aInclusive;
end;

function TGLiteTreeSet.TTail.GetEnumerator: TTailEnumerator;
begin
  Result := FSet^.GetTailEnumerator(FLowBound, FInclusive);
end;

{ TGLiteTreeSet.TRange }

constructor TGLiteTreeSet.TRange.Create(aSet: PSet; const aLowBound, aHighBound: T; aBounds: TRangeBounds);
begin
  FSet := aSet;
  FLowBound := aLowBound;
  FHighBound := aHighBound;
  FBounds := aBounds;
end;

function TGLiteTreeSet.TRange.GetEnumerator: TRangeEnumerator;
begin
  Result := FSet^.GetRangeEnumerator(FLowBound, FHighBound, FBounds);
end;

{ TGLiteTreeSet }

function TGLiteTreeSet.GetCapacity: SizeInt;
begin
  Result := FTree.Capacity;
end;

function TGLiteTreeSet.GetCount: SizeInt;
begin
  Result := FTree.Count;
end;

function TGLiteTreeSet.FindNearestLT(const aPattern: T; out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.FindLess(aPattern);
  Result := I > 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.FindNearestLE(const aPattern: T; out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.FindLessOrEqual(aPattern);
  Result := I > 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.FindNearestGT(const aPattern: T; out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.FindGreater(aPattern);
  Result := I > 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.FindNearestGE(const aPattern: T; out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.FindGreaterOrEqual(aPattern);
  Result := I > 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := TReverseEnumerator.Create(Self);
end;

function TGLiteTreeSet.GetHeadEnumerator(const aHighBound: T; aInclusive: Boolean): THeadEnumerator;
begin
  Result := THeadEnumerator.Create(Self, aHighBound, aInclusive);
end;

function TGLiteTreeSet.GetTailEnumerator(const aLowBound: T; aInclusive: Boolean): TTailEnumerator;
begin
  Result := TTailEnumerator.Create(Self, aLowBound, aInclusive);
end;

function TGLiteTreeSet.GetRangeEnumerator(const aLowBound, aHighBound: T;
  aBounds: TRangeBounds): TRangeEnumerator;
begin
  Result := TRangeEnumerator.Create(Self, aLowBound, aHighBound, aBounds);
end;

function TGLiteTreeSet.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

function TGLiteTreeSet.Reverse: TReverse;
begin
  Result := TReverse.Create(@Self);
end;

function TGLiteTreeSet.ToArray: TArray;
var
  I: SizeInt = 0;
  p: PEntry;
begin
  System.SetLength(Result, Count);
  for p in FTree do
    begin
      Result[I] := p^.Key;
      Inc(I);
    end;
end;

function TGLiteTreeSet.IsEmpty: Boolean;
begin
  Result := FTree.Count = 0;
end;

function TGLiteTreeSet.NonEmpty: Boolean;
begin
  Result := FTree.Count <> 0;
end;

procedure TGLiteTreeSet.Clear;
begin
  FTree.Clear;
end;

procedure TGLiteTreeSet.TrimToFit;
begin
  FTree.TrimToFit;
end;

procedure TGLiteTreeSet.EnsureCapacity(aValue: SizeInt);
begin
  FTree.EnsureCapacity(aValue);
end;

function TGLiteTreeSet.Add(const aValue: T): Boolean;
var
  p: PEntry;
begin
  Result := not FTree.FindOrAdd(aValue, p);
end;

function TGLiteTreeSet.AddAll(const a: array of T): SizeInt;
var
  v: T;
begin
  Result := Count;
  for v in a do
    Add(v);
  Result := Count - Result;
end;

function TGLiteTreeSet.AddAll(e: IEnumerable): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        Add(Current);
    finally
      Free;
    end;
  Result := Count - Result;
end;

function TGLiteTreeSet.AddAll(constref aSet: TGLiteTreeSet): SizeInt;
begin
  if @aSet <> @Self then
    begin
      Result := Count;
      with aSet.GetEnumerator do
        while MoveNext do
          Add(Current);
      Result := Count - Result;
    end
  else
    Result := 0;
end;

function TGLiteTreeSet.Contains(const aValue: T): Boolean;
begin
  Result := FTree.Find(aValue) <> nil;
end;

function TGLiteTreeSet.NonContains(const aValue: T): Boolean;
begin
  Result := FTree.Find(aValue) = nil;
end;

function TGLiteTreeSet.ContainsAny(const a: array of T): Boolean;
var
  v: T;
begin
  for v in a do
    if Contains(v) then
      exit(True);
  Result := False;
end;

function TGLiteTreeSet.ContainsAny(e: IEnumerable): Boolean;
begin
  with e.GetEnumerator do
    try
      while MoveNext do
        if Contains(Current) then
          exit(True);
    finally
      Free;
    end;
  Result := False;
end;

function TGLiteTreeSet.ContainsAny(constref aSet: TGLiteTreeSet): Boolean;
begin
  if @aSet = @Self then
    exit(True);
  with aSet.GetEnumerator do
    while MoveNext do
      if Contains(Current) then
        exit(True);
  Result := False;
end;

function TGLiteTreeSet.ContainsAll(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to System.High(a) do
    if NonContains(a[I]) then
      exit(False);
  Result := True;
end;

function TGLiteTreeSet.ContainsAll(e: IEnumerable): Boolean;
begin
  with e.GetEnumerator do
    try
      while MoveNext do
        if NonContains(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGLiteTreeSet.ContainsAll(constref aSet: TGLiteTreeSet): Boolean;
begin
  if @aSet = @Self then
    exit(True);
  if IsEmpty then exit(aSet.IsEmpty);
  with aSet.GetEnumerator do
    while MoveNext do
      if NonContains(Current) then
        exit(False);
  Result := True;
end;

function TGLiteTreeSet.Remove(const aValue: T): Boolean;
begin
  Result := FTree.Remove(aValue);
end;

function TGLiteTreeSet.RemoveAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if Remove(a[I]) and IsEmpty then
          break;
      Result := Result - Count;
    end;
end;

function TGLiteTreeSet.RemoveAll(e: IEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if Remove(Current) and IsEmpty then
              break;
        finally
          Free;
        end;
      Result := Result - Count;
    end
  else
    e.Discard;
end;

function TGLiteTreeSet.RemoveAll(constref aSet: TGLiteTreeSet): SizeInt;
begin
  if @aSet <> @Self then
    begin
      Result := Count;
      if Result > 0 then
        begin
          with aSet.GetEnumerator do
            while MoveNext do
              if Remove(Current) and IsEmpty then
                break;
          Result := Result - Count;
        end;
    end
  else
    begin
      Result := Count;
      Clear;
    end;
end;

function TGLiteTreeSet.RemoveIf(aTest: TTest): SizeInt;
var
  List: TTree.TNodeList;
  I: SizeInt = 1;
begin
  Result := Count;
  if NonEmpty then
    begin
      List := FTree.NodeList;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          FTree.RemoveAt(I)
        else
          Inc(I);
    end;
  Result := Result - Count;
end;

function TGLiteTreeSet.RemoveIf(aTest: TOnTest): SizeInt;
var
  List: TTree.TNodeList;
  I: SizeInt = 1;
begin
  Result := Count;
  if NonEmpty then
    begin
      List := FTree.NodeList;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          FTree.RemoveAt(I)
        else
          Inc(I);
    end;
  Result := Result - Count;
end;

function TGLiteTreeSet.RemoveIf(aTest: TNestTest): SizeInt;
var
  List: TTree.TNodeList;
  I: SizeInt = 1;
begin
  Result := Count;
  if NonEmpty then
    begin
      List := FTree.NodeList;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          FTree.RemoveAt(I)
        else
          Inc(I);
    end;
  Result := Result - Count;
end;

function TGLiteTreeSet.Extract(const aValue: T): Boolean;
begin
  Result := FTree.Remove(aValue);
end;

function TGLiteTreeSet.ExtractIf(aTest: TTest): TArray;
var
  List: TTree.TNodeList;
  I, J: SizeInt;
begin
  Result := nil;
  if NonEmpty then
    begin
      System.SetLength(Result, ARRAY_INITIAL_SIZE);
      List := FTree.NodeList;
      I := 1;
      J := 0;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          begin
            if J = System.Length(Result) then
              System.SetLength(Result, J shl 1);
            Result[J] := List[I].Data.Key;
            FTree.RemoveAt(I);
            Inc(J);
          end
        else
          Inc(I);
      System.SetLength(Result, J);
    end;
end;

function TGLiteTreeSet.ExtractIf(aTest: TOnTest): TArray;
var
  List: TTree.TNodeList;
  I, J: SizeInt;
begin
  Result := nil;
  if NonEmpty then
    begin
      System.SetLength(Result, ARRAY_INITIAL_SIZE);
      List := FTree.NodeList;
      I := 1;
      J := 0;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          begin
            if J = System.Length(Result) then
              System.SetLength(Result, J shl 1);
            Result[J] := List[I].Data.Key;
            FTree.RemoveAt(I);
            Inc(J);
          end
        else
          Inc(I);
      System.SetLength(Result, J);
    end;
end;

function TGLiteTreeSet.ExtractIf(aTest: TNestTest): TArray;
var
  List: TTree.TNodeList;
  I, J: SizeInt;
begin
  Result := nil;
  if NonEmpty then
    begin
      System.SetLength(Result, ARRAY_INITIAL_SIZE);
      List := FTree.NodeList;
      I := 1;
      J := 0;
      while I <= FTree.Count do
        if aTest(List[I].Data.Key) then
          begin
            if J = System.Length(Result) then
              System.SetLength(Result, J shl 1);
            Result[J] := List[I].Data.Key;
            FTree.RemoveAt(I);
            Inc(J);
          end
        else
          Inc(I);
      System.SetLength(Result, J);
    end;
end;

procedure TGLiteTreeSet.RetainAll(aCollection: ICollection);
var
  List: TTree.TNodeList;
  I: SizeInt = 1;
begin
  if NonEmpty then
    begin
      List := FTree.NodeList;
      while I <= FTree.Count do
        if aCollection.NonContains(List[I].Data.Key) then
          FTree.RemoveAt(I)
        else
          Inc(I);
    end;
end;

procedure TGLiteTreeSet.RetainAll(constref aSet: TGLiteTreeSet);
var
  List: TTree.TNodeList;
  I: SizeInt = 1;
begin
  if NonEmpty and (@aSet <> @Self) then
    begin
      List := FTree.NodeList;
      while I <= FTree.Count do
        if aSet.NonContains(List[I].Data.Key) then
          FTree.RemoveAt(I)
        else
          Inc(I);
    end;
end;

function TGLiteTreeSet.IsSuperset(constref aSet: TGLiteTreeSet): Boolean;
begin
  Result := ContainsAll(aSet);
end;

function TGLiteTreeSet.IsSubset(constref aSet: TGLiteTreeSet): Boolean;
begin
  Result := aSet.IsSuperset(Self);
end;

function TGLiteTreeSet.IsEqual(constref aSet: TGLiteTreeSet): Boolean;
begin
  if @aSet <> @Self then
    begin
      if Count <> aSet.Count then
        exit(False);
      with aSet.GetEnumerator do
        while MoveNext do
          if NonContains(Current) then
            exit(False);
      Result := True;
    end
  else
    Result := True;
end;

function TGLiteTreeSet.Intersecting(constref aSet: TGLiteTreeSet): Boolean;
begin
  if @aSet <> @Self then
    begin
      with aSet.GetEnumerator do
        while MoveNext do
          if Contains(Current) then
            exit(True);
      Result := False;
    end
  else
    Result := NonEmpty;
end;

procedure TGLiteTreeSet.Intersect(constref aSet: TGLiteTreeSet);
begin
  RetainAll(aSet);
end;

procedure TGLiteTreeSet.Join(constref aSet: TGLiteTreeSet);
begin
  AddAll(aSet);
end;

procedure TGLiteTreeSet.Subtract(constref aSet: TGLiteTreeSet);
begin
  RemoveAll(aSet);
end;

procedure TGLiteTreeSet.SymmetricSubtract(constref aSet: TGLiteTreeSet);
var
  v: T;
begin
  if @aSet <> @Self then
    begin
      for v in aSet do
        if not Remove(v) then
          Add(v);
    end
  else
    Clear;
end;

function TGLiteTreeSet.FindMin(out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.Lowest;
  Result := I >= 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.FindMax(out aValue: T): Boolean;
var
  I: SizeInt;
begin
  I := FTree.Highest;
  Result := I >= 0;
  if Result then
    aValue := FTree.NodeList[I].Data.Key;
end;

function TGLiteTreeSet.FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestGE(aValue, aCeil)
  else
    Result := FindNearestGT(aValue, aCeil);
end;

function TGLiteTreeSet.FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestLE(aValue, aFloor)
  else
    Result := FindNearestLT(aValue, aFloor);
end;

function TGLiteTreeSet.Head(const aHighBound: T; aInclusive: Boolean): THead;
begin
  Result := THead.Create(@Self, aHighBound, aInclusive);
end;

function TGLiteTreeSet.Tail(const aLowBound: T; aInclusive: Boolean): TTail;
begin
   Result := TTail.Create(@Self, aLowBound, aInclusive);
end;

function TGLiteTreeSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TRange;
begin
  Result := TRange.Create(@Self, aLowBound, aHighBound, aIncludeBounds);
end;

function TGLiteTreeSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGLiteTreeSet;
var
  v: T;
begin
  for v in Head(aHighBound, aInclusive) do
    Result.Add(v);
end;

function TGLiteTreeSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGLiteTreeSet;
var
  v: T;
begin
  for v in Tail(aLowBound, aInclusive) do
    Result.Add(v);
end;

function TGLiteTreeSet.SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TGLiteTreeSet;
var
  v: T;
begin
  for v in Range(aLowBound, aHighBound, aIncludeBounds) do
    Result.Add(v);
end;

class operator TGLiteTreeSet. + (constref L, R: TGLiteTreeSet): TGLiteTreeSet;
begin
  Result := L;
  Result.Join(R);
end;

class operator TGLiteTreeSet. - (constref L, R: TGLiteTreeSet): TGLiteTreeSet;
var
  v: T;
begin
  for v in L do
    if R.NonContains(v) then
      Result.Add(v);
end;

class operator TGLiteTreeSet. * (constref L, R: TGLiteTreeSet): TGLiteTreeSet;
begin
  Result := L;
  Result.Intersect(R);
end;

class operator TGLiteTreeSet.><(constref L, R: TGLiteTreeSet): TGLiteTreeSet;
begin
  Result := L;
  Result.SymmetricSubtract(R);
end;

class operator TGLiteTreeSet.in(constref aValue: T; const aSet: TGLiteTreeSet): Boolean;
begin
  Result := aSet.Contains(aValue);
end;

class operator TGLiteTreeSet. = (constref L, R: TGLiteTreeSet): Boolean;
begin
  Result := L.IsEqual(R);
end;

class operator TGLiteTreeSet.<=(constref L, R: TGLiteTreeSet): Boolean;
begin
  Result := L.IsSubset(R);
end;

end.

