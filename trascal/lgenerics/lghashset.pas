{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic hashset implementations.                                        *
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
unit lgHashSet;

{$MODE OBJFPC}{$H+}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgAbstractContainer,
  lgHashTable,
  lgStrConst;

type

  {TGAbstractHashSet: common abstract ancestor hashset class }
  generic TGAbstractHashSet<T> = class abstract(specialize TGAbstractSet<T>)
  public
  type
    TAbstractHashSet = specialize TGAbstractHashSet<T>;

  protected
  type
    THashTable      = specialize TGAbstractHashTable<T, TEntry>;
    THashTableClass = class of THashTable;
    THashSetClass   = class of TAbstractHashSet;
    TSearchResult   = THashTable.TSearchResult;

    TEnumerator = class(TContainerEnumerator)
    private
      FEnum: THashTable.TEntryEnumerator;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(hs: TAbstractHashSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TDistinctEnumerable = class(specialize TGEnumCursor<T>)
    protected
      FSet: TAbstractHashSet;
    public
      constructor Create(e: TSpecEnumerator; aSetClass: THashSetClass);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FTable: THashTable;
    function  GetCount: SizeInt; override;
    function  GetCapacity: SizeInt; override;
    function  GetExpandTreshold: SizeInt; inline;
    function  GetFillRatio: Single; inline;
    function  GetLoadFactor: Single; inline;
    procedure SetLoadFactor(aValue: Single); inline;
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
    class function GetClass: THashSetClass; virtual; abstract;
    class function GetTableClass: THashTableClass; virtual; abstract;
  public
    class function DefaultLoadFactor: Single; inline;
    class function MaxLoadFactor: Single; inline;
    class function MinLoadFactor: Single; inline;
    class function Distinct(const a: TArray): IEnumerable; inline;
    class function Distinct(e: IEnumerable): IEnumerable; inline;
    constructor Create;
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor Create(aCapacity: SizeInt);
    constructor Create(aCapacity: SizeInt; const a: array of T);
    constructor Create(aCapacity: SizeInt; e: IEnumerable);
    constructor Create(aLoadFactor: Single);
    constructor Create(aLoadFactor: Single; const a: array of T);
    constructor Create(aLoadFactor: Single; e: IEnumerable);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable);
    constructor CreateCopy(aSet: TAbstractHashSet);
    destructor Destroy; override;
    function  Contains(const aValue: T): Boolean; override;
    function  Clone: TAbstractHashSet; override;
    property  LoadFactor: Single read GetLoadFactor write SetLoadFactor;
    property  FillRatio: Single read GetFillRatio;
  { The number of elements that can be written without rehashing }
    property  ExpandTreshold: SizeInt read GetExpandTreshold;
  end;

  { TGBaseHashSetLP implements open addressing hashset with linear probing;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGBaseHashSetLP<T, TEqRel> = class(specialize TGAbstractHashSet<T>)
  protected
    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  end;

  { TGHashSetLP implements open addressing hashset with linear probing;
    it assumes that type T implements TEqRel }
  generic TGHashSetLP<T> = class(specialize TGBaseHashSetLP<T, T>);

  { TGBaseHashSetLPT implements open addressing hashset with linear probing and lazy deletion }
  generic TGBaseHashSetLPT<T, TEqRel> = class(specialize TGAbstractHashSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableLPT = specialize TGOpenAddrLPT<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashSetClass; override;
  public
    procedure ClearTombstones;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGHashSetLPT implements open addressing hashset with linear probing and lazy deletion;
    it assumes that type T implements TEqRel }
  generic TGHashSetLPT<T> = class(specialize TGBaseHashSetLPT<T, T>);

  { TGBaseHashSetQP implements open addressing hashset with quadratic probing(c1 = c2 = 1/2) }
  generic TGBaseHashSetQP<T, TEqRel> = class(specialize TGAbstractHashSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableQP = specialize TGOpenAddrQP<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashSetClass; override;
  public
    procedure ClearTombstones;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGHashSetQP implements open addressing hashset with quadratic probing(c1 = c2 = 1/2);
    it assumes that type T implements TEqRel }
  generic TGHashSetQP<T> = class(specialize TGBaseHashSetQP<T, T>);

  { TGBaseOrderedHashSet implements node based hashset with predictable iteration order,
    which is the order in which elements were inserted into the set (insertion-order) }
  generic TGBaseOrderedHashSet<T, TEqRel> = class(specialize TGAbstractHashSet<T>)
  protected
  type
    TOrderedHashTable = specialize TGOrderedHashTable<T, TEntry, TEqRel>;
    PNode             = TOrderedHashTable.PNode;

    TReverseEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TOrderedHashTable.TReverseEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(aSet: TGBaseOrderedHashSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    function Reverse: IEnumerable; override;
  end;

  { TGOrderedHashSet implements node based hashset with predictable iteration order,
    which is the order in which elements were inserted into the set(insertion-order);
    it assumes that type T implements TEqRel }
  generic TGOrderedHashSet<T> = class(specialize TGBaseOrderedHashSet<T, T>);

  { TGBaseChainHashSet implements node based hashset with singly linked list chains }
  generic TGBaseChainHashSet<T, TEqRel> = class(specialize TGAbstractHashSet<T>)
  protected
    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  end;

  { TGChainHashSet implements node based hashset with singly linked list chains;
    it assumes that type T implements TEqRel }
  generic TGChainHashSet<T> = class(specialize TGBaseChainHashSet<T, T>);

  generic TGCustomObjectHashSet<T: class> = class abstract(specialize TGAbstractHashSet<T>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure EntryRemoving(p: PEntry);
    procedure DoClear; override;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aSet: TGCustomObjectHashSet);
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGObjectHashSetLP<T: class; TEqRel> = class(specialize TGCustomObjectHashSet<T>)
  protected
    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    function  Clone: TGObjectHashSetLP; override;
  end;

 { TGObjHashSetLP assumes that type T implements TEqRel }
  generic TGObjHashSetLP<T: class> = class(specialize TGObjectHashSetLP<T, T>);

  generic TGObjectHashSetLPT<T: class; TEqRel> = class(specialize TGCustomObjectHashSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableLPT = specialize TGOpenAddrLPT<T, TEntry, TEqRel>;

    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    function  Clone: TGObjectHashSetLPT; override;
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGObjHashSetLPT assumes that type T implements TEqRel }
  generic TGObjHashSetLPT<T: class> = class(specialize TGObjectHashSetLPT<T, T>);

  generic TGObjectHashSetQP<T: class; TEqRel> = class(specialize TGCustomObjectHashSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableQP = specialize TGOpenAddrQP<T, TEntry, TEqRel>;

    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    function  Clone: TGObjectHashSetQP; override;
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGObjHashSetQP assumes that type T implements TEqRel }
  generic TGObjHashSetQP<T: class> = class(specialize TGObjectHashSetQP<T, T>);

  generic TGObjectOrderedHashSet<T: class; TEqRel> = class(specialize TGBaseOrderedHashSet<T, TEqRel>)
  private
    FOwnsObjects: Boolean;
  protected
  type
    TObjectOrderedHashSet = TGObjectOrderedHashSet;

    procedure EntryRemoving(p: PEntry);
    procedure DoClear; override;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aSet: TGObjectOrderedHashSet);
    function  Clone: TGObjectOrderedHashSet; override;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  { TGObjOrderedHashSet assumes that type T implements TEqRel }
  generic TGObjOrderedHashSet<T: class> = class(specialize TGObjectOrderedHashSet<T, T>);

  generic TGObjectChainHashSet<T: class; TEqRel> = class(specialize TGCustomObjectHashSet<T>)
  protected
    class function GetClass: THashSetClass; override;
    class function GetTableClass: THashTableClass; override;
  public
    function Clone: TGObjectChainHashSet; override;
  end;

  { TGObjChainHashSet assumes that type T implements TEqRel }
  generic TGObjChainHashSet<T: class> = class(specialize TGObjectChainHashSet<T, T>);

  { TGLiteHashSet }
  generic TGLiteHashSet<T, TEntry, TTable, TTblEnumerator, TTblRemovableEnumerator> = record
  private
  type
    PEntry = ^TEntry;
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
      FEnum: TTblEnumerator;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

  private
    FTable: TTable;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    function  GetFillRatio: Single; inline;
    function  GetLoadFactor: Single; inline;
    function  GetExpandTreshold: SizeInt; inline;
    procedure SetLoadFactor(aValue: Single); inline;
  public
    function  DefaultLoadFactor: Single; inline;
    function  MaxLoadFactor: Single; inline;
    function  MinLoadFactor: Single; inline;
    function  GetEnumerator: TEnumerator;
    function  ToArray: TArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear; inline;
    procedure TrimToFit; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
  { returns True if the element is added }
    function  Add(const aValue: T): Boolean; inline;
  { returns count of added elements }
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
    function  AddAll(constref aSet: TGLiteHashSet): SizeInt;
    function  Contains(const aValue: T): Boolean;
    function  NonContains(const aValue: T): Boolean;
    function  FindFirst(out aValue: T): Boolean; inline;
    function  ContainsAny(const a: array of T): Boolean;
    function  ContainsAny(e: IEnumerable): Boolean;
    function  ContainsAny(constref aSet: TGLiteHashSet): Boolean;
    function  ContainsAll(const a: array of T): Boolean;
    function  ContainsAll(e: IEnumerable): Boolean;
    function  ContainsAll(constref aSet: TGLiteHashSet): Boolean;
  { returns True if the element is removed }
    function  Remove(const aValue: T): Boolean; inline;
  { returns count of removed elements }
    function  RemoveAll(const a: array of T): SizeInt;
    function  RemoveAll(e: IEnumerable): SizeInt;
    function  RemoveAll(constref aSet: TGLiteHashSet): SizeInt;
  { returns count of removed elements }
    function  RemoveIf(aTest: TTest): SizeInt;
    function  RemoveIf(aTest: TOnTest): SizeInt;
    function  RemoveIf(aTest: TNestTest): SizeInt;
  { returns True if the element is extracted }
    function  Extract(const aValue: T): Boolean; inline;
    function  ExtractIf(aTest: TTest): TArray;
    function  ExtractIf(aTest: TOnTest): TArray;
    function  ExtractIf(aTest: TNestTest): TArray;
  { will contain only those elements that are simultaneously contained in self and aCollection/aSet }
    procedure RetainAll(aCollection: ICollection);
    procedure RetainAll(constref aSet: TGLiteHashSet);
    function  IsSuperset(constref aSet: TGLiteHashSet): Boolean;
    function  IsSubset(constref aSet: TGLiteHashSet): Boolean;
    function  IsEqual(constref aSet: TGLiteHashSet): Boolean;
    function  Intersecting(constref aSet: TGLiteHashSet): Boolean;
    procedure Intersect(constref aSet: TGLiteHashSet);
    procedure Join(constref aSet: TGLiteHashSet);
    procedure Subtract(constref aSet: TGLiteHashSet);
    procedure SymmetricSubtract(constref aSet: TGLiteHashSet);
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  LoadFactor: Single read GetLoadFactor write SetLoadFactor;
    property  FillRatio: Single read GetFillRatio;
    property  ExpandTreshold: SizeInt read GetExpandTreshold;
    class operator +(constref L, R: TGLiteHashSet): TGLiteHashSet;
    class operator -(constref L, R: TGLiteHashSet): TGLiteHashSet;
    class operator *(constref L, R: TGLiteHashSet): TGLiteHashSet;
    class operator ><(constref L, R: TGLiteHashSet): TGLiteHashSet;
    class operator =(constref L, R: TGLiteHashSet): Boolean; inline;
    class operator <=(constref L, R: TGLiteHashSet): Boolean; inline;
    class operator in(constref aValue: T; constref aSet: TGLiteHashSet): Boolean; inline;
  end;

  { TGLiteHashSetLP implements open addressing hashset with linear probing;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteHashSetLP<T, TEqRel> = record
  private
  type
    TEntry = record Key: T; end;
    TTable = specialize TGLiteHashTableLP<T, TEntry, TEqRel>;
  public
  type
    TSet = specialize TGLiteHashSet<T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  end;

  { TGLiteChainHashSet implements node based hashset with load factor 1.0;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteChainHashSet<T, TEqRel> = record
  private
  type
    TEntry = record Key: T; end;
    TTable = specialize TGLiteChainHashTable<T, TEntry, TEqRel>;
  public
  type
    TSet = specialize TGLiteHashSet<T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  end;

  { TGLiteEquatableHashSet: open addressing hashset with linear probing and
    constant load factor 0.5; for types having a defined fast operator "=";
      functor THashFun must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt; }
  generic TGLiteEquatableHashSet<T, THashFun> = record
  private
  type
    TEntry = record Key: T; end;
    TTable = specialize TGLiteEquatableHashTable<T, TEntry, THashFun>;
  public
  type
    TSet = specialize TGLiteHashSet<T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  end;

  { TGDisjointSetUnion: see https://en.wikipedia.org/wiki/Disjoint-set_data_structure }
  generic TGDisjointSetUnion<T, TEqRel> = record
  private
  type
    TEntry = record
      Key: T;
    end;
    PEntry = ^TEntry;

    TTable = specialize TGLiteChainHashTable<T, TEntry, TEqRel>;
    PNode  = TTable.PNode;

  public
  type
    TArray = array of T;

    TEnumerator = record
    private
      FList: PNode;
      FCurrIndex,
      FLastIndex: SizeInt;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

  private
    FTable: TTable;
    FDsu: array of SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    function  FindOrAdd(const aValue: T): SizeInt;
    procedure ExpandDsu;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetTag(aValue: SizeInt): SizeInt;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  ToArray: TArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    function  IndexOf(const aValue: T): SizeInt;
    function  Contains(const aValue: T): Boolean; inline;
    function  NonContains(const aValue: T): Boolean; inline;
  { returns index of the added element, -1 if such element already exists }
    function  Add(const aValue: T): SizeInt;
  { destroys subsets }
    procedure Reset;
  { values related to the same subset will have the same Tag }
    function  Tag(const aValue: T): SizeInt;
    function  TagI(aIndex: SizeInt): SizeInt;
    function  InSameSet(const L, R: T): Boolean; inline;
    function  InSameSetI(L, R: SizeInt): Boolean; inline;
    function  InDiffSets(const L, R: T): Boolean; inline;
    function  InDiffSetsI(L, R: SizeInt): Boolean; inline;
  { returns True and joins L and R, if L and R related to the different subsets, False otherwise }
    function  Join(const L, R: T): Boolean; inline;
    function  JoinI(L, R: SizeInt): Boolean;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem; default;
  end;

  { TGThreadFGHashSet: fine-grained concurrent set;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGThreadFGHashSet<T, TEqRel> = class
  private
  type
    PNode = ^TNode;
    TNode = record
      Hash: SizeInt;
      Value: T;
      Next: PNode;
    end;

    TSlot = record
    strict private
      FState: SizeUInt;
      class operator Initialize(var aSlot: TSlot);
    public
      Head: PNode;
      procedure Lock; inline;
      procedure Unlock; inline;
    end;

  var
    FSlotList: array of TSlot;
    FCount: SizeInt;
    FLoadFactor: Single;
    FGlobLock: TMultiReadExclusiveWriteSynchronizer;
    function  NewNode(const aValue: T; aHash: SizeInt): PNode;
    procedure FreeNode(aNode: PNode);
    function  GetCapacity: SizeInt;
    procedure ClearChainList;
    function  LockSlot(const aValue: T; out aHash: SizeInt): SizeInt;
    function  Find(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
    function  RemoveNode(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
    procedure CheckNeedExpand;
    procedure Expand;
  public
  const
    MIN_LOAD_FACTOR: Single     = 0.5;
    MAX_LOAD_FACTOR: Single     = 8.0;
    DEFAULT_LOAD_FACTOR: Single = 1.0;

    constructor Create;
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single = 1.0);
    destructor Destroy; override;
    function  Add(const aValue: T): Boolean;
    function  Contains(const aValue: T): Boolean;
    function  Remove(const aValue: T): Boolean; virtual;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  LoadFactor: Single read FLoadFactor;
  end;

  { TGThreadHashSetFG: fine-grained concurrent set attempt;
    it assumes that type T implements TEqRel }
  generic TGThreadHashSetFG<T> = class(specialize TGThreadFGHashSet<T, T>);

implementation
{$B-}{$COPERATORS ON}

{ TGAbstractHashSet.TEnumerator }

function TGAbstractHashSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.GetCurrent^.Key;
end;

constructor TGAbstractHashSet.TEnumerator.Create(hs: TAbstractHashSet);
begin
  inherited Create(hs);
  FEnum := hs.FTable.GetEnumerator;
end;

destructor TGAbstractHashSet.TEnumerator.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractHashSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractHashSet.TEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractHashSet.TDistinctEnumerable }

constructor TGAbstractHashSet.TDistinctEnumerable.Create(e: TSpecEnumerator; aSetClass: THashSetClass);
begin
  inherited Create(e);
  FSet := aSetClass.Create;
end;

destructor TGAbstractHashSet.TDistinctEnumerable.Destroy;
begin
  FSet.Free;
  inherited;
end;

function TGAbstractHashSet.TDistinctEnumerable.MoveNext: Boolean;
begin
  repeat
    if not inherited MoveNext then
      exit(False);
    Result := FSet.Add(Current);
  until Result;
end;

procedure TGAbstractHashSet.TDistinctEnumerable.Reset;
begin
  inherited;
  FSet.Clear;
end;

{ TGAbstractHashSet }

function TGAbstractHashSet.GetExpandTreshold: SizeInt;
begin
  Result := FTable.ExpandTreshold;
end;

function TGAbstractHashSet.GetCount: SizeInt;
begin
  Result := FTable.Count;
end;

function TGAbstractHashSet.GetCapacity: SizeInt;
begin
  Result := FTable.Capacity;
end;

function TGAbstractHashSet.GetFillRatio: Single;
begin
  Result := FTable.FillRatio;
end;

function TGAbstractHashSet.GetLoadFactor: Single;
begin
  Result := FTable.LoadFactor;
end;

procedure TGAbstractHashSet.SetLoadFactor(aValue: Single);
begin
  FTable.LoadFactor := aValue;
end;

function TGAbstractHashSet.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGAbstractHashSet.DoClear;
begin
  FTable.Clear;
end;

procedure TGAbstractHashSet.DoTrimToFit;
begin
  FTable.TrimToFit;
end;

procedure TGAbstractHashSet.DoEnsureCapacity(aValue: SizeInt);
begin
  FTable.EnsureCapacity(aValue);
end;

function TGAbstractHashSet.DoAdd(const aValue: T): Boolean;
var
  p: PEntry;
  sr: TSearchResult;
begin
  Result := not FTable.FindOrAdd(aValue, p, sr);
  if Result then
    p^.Key := aValue;
end;

function TGAbstractHashSet.DoExtract(const aValue: T): Boolean;
begin
  Result := FTable.Remove(aValue);
end;

function TGAbstractHashSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := FTable.RemoveIf(aTest);
end;

function TGAbstractHashSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := FTable.RemoveIf(aTest);
end;

function TGAbstractHashSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := FTable.RemoveIf(aTest);
end;

function TGAbstractHashSet.DoExtractIf(aTest: TTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

function TGAbstractHashSet.DoExtractIf(aTest: TOnTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

function TGAbstractHashSet.DoExtractIf(aTest: TNestTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
end;

class function TGAbstractHashSet.DefaultLoadFactor: Single;
begin
  Result := GetTableClass.DefaultLoadFactor;
end;

class function TGAbstractHashSet.MaxLoadFactor: Single;
begin
  Result := GetTableClass.MaxLoadFactor;
end;

class function TGAbstractHashSet.MinLoadFactor: Single;
begin
  Result := GetTableClass.MinLoadFactor;
end;

class function TGAbstractHashSet.Distinct(const a: TArray): IEnumerable;
begin
  Result := TDistinctEnumerable.Create(specialize TGArrayEnumerator<T>.Create(a), GetClass);
end;

class function TGAbstractHashSet.Distinct(e: IEnumerable): IEnumerable;
begin
  Result := TDistinctEnumerable.Create(e.GetEnumerator, GetClass);
end;

constructor TGAbstractHashSet.Create;
begin
  FTable := GetTableClass.Create;
end;

constructor TGAbstractHashSet.Create(const a: array of T);
begin
  FTable := GetTableClass.Create;
  DoAddAll(a);
end;

constructor TGAbstractHashSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TAbstractHashSet then
    CreateCopy(TAbstractHashSet(o))
  else
    begin
      if o is TSpecSet then
        Create(TSpecSet(o).Count)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt);
begin
  FTable := GetTableClass.Create(aCapacity);
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt; const a: array of T);
begin
  FTable := GetTableClass.Create(aCapacity);
  DoAddAll(a);
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt; e: IEnumerable);
begin
  FTable := GetTableClass.Create(aCapacity);
  DoAddAll(e);
end;

constructor TGAbstractHashSet.Create(aLoadFactor: Single);
begin
  FTable := GetTableClass.Create(aLoadFactor);
end;

constructor TGAbstractHashSet.Create(aLoadFactor: Single; const a: array of T);
begin
  FTable := GetTableClass.Create(aLoadFactor);
  DoAddAll(a);
end;

constructor TGAbstractHashSet.Create(aLoadFactor: Single; e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecSet then
    Create(TSpecSet(o).Count, aLoadFactor)
  else
    Create(aLoadFactor);
  DoAddAll(e);
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
  DoAddAll(a);
end;

constructor TGAbstractHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
  DoAddAll(e);
end;

constructor TGAbstractHashSet.CreateCopy(aSet: TAbstractHashSet);
begin
  if aSet.GetClass = GetClass then
    FTable := aSet.FTable.Clone
  else
    begin
      FTable := GetTableClass.Create(aSet.Count);
      DoAddAll(aSet);
    end;
end;

destructor TGAbstractHashSet.Destroy;
begin
  DoClear;
  FTable.Free;
  inherited;
end;

function TGAbstractHashSet.Contains(const aValue: T): Boolean;
var
  sr: TSearchResult;
begin
  Result := FTable.Find(aValue, sr) <> nil;
end;

function TGAbstractHashSet.Clone: TAbstractHashSet;
begin
  Result := GetClass.CreateCopy(Self);
end;

{ TGBaseHashSetLP }

class function TGBaseHashSetLP.GetClass: THashSetClass;
begin
  Result := TGBaseHashSetLP;
end;

class function TGBaseHashSetLP.GetTableClass: THashTableClass;
begin
  Result := specialize TGOpenAddrLP<T, TEntry, TEqRel>;
end;

{ TGBaseHashSetLPT }

function TGBaseHashSetLPT.GetTombstonesCount: SizeInt;
begin
  Result :=  THashTableLPT(FTable).TombstonesCount;
end;

class function TGBaseHashSetLPT.GetTableClass: THashTableClass;
begin
  Result := THashTableLPT;
end;

class function TGBaseHashSetLPT.GetClass: THashSetClass;
begin
  Result := TGBaseHashSetLPT;
end;

procedure TGBaseHashSetLPT.ClearTombstones;
begin
  THashTableLPT(FTable).ClearTombstones;
end;

{ TGBaseHashSetQP }

function TGBaseHashSetQP.GetTombstonesCount: SizeInt;
begin
  Result := THashTableQP(FTable).TombstonesCount;
end;

class function TGBaseHashSetQP.GetTableClass: THashTableClass;
begin
  Result := THashTableQP;
end;

class function TGBaseHashSetQP.GetClass: THashSetClass;
begin
  Result := TGBaseHashSetQP;
end;

procedure TGBaseHashSetQP.ClearTombstones;
begin
  THashTableQP(FTable).ClearTombstones;
end;

{ TGBaseOrderedHashSet.TReverseEnumerable }

function TGBaseOrderedHashSet.TReverseEnumerable.GetCurrent: T;
begin
  Result := FEnum.GetCurrent^.Key;
end;

constructor TGBaseOrderedHashSet.TReverseEnumerable.Create(aSet: TGBaseOrderedHashSet);
begin
  inherited Create(aSet);
  FEnum := TOrderedHashTable(aSet.FTable).GetReverseEnumerator;
end;

destructor TGBaseOrderedHashSet.TReverseEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGBaseOrderedHashSet.TReverseEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGBaseOrderedHashSet.TReverseEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGBaseOrderedHashSet }

class function TGBaseOrderedHashSet.GetClass: THashSetClass;
begin
  Result := TGBaseOrderedHashSet;
end;

class function TGBaseOrderedHashSet.GetTableClass: THashTableClass;
begin
  Result := TOrderedHashTable;
end;

function TGBaseOrderedHashSet.Reverse: IEnumerable;
begin
  BeginIteration;
  Result := TReverseEnumerable.Create(Self);
end;

{ TGBaseChainHashSet }

class function TGBaseChainHashSet.GetClass: THashSetClass;
begin
  Result := TGBaseChainHashSet;
end;

class function TGBaseChainHashSet.GetTableClass: THashTableClass;
begin
  Result := specialize TGChainHashTable<T, TEntry, TEqRel>;
end;

{ TGCustomObjectHashSet }

procedure TGCustomObjectHashSet.EntryRemoving(p: PEntry);
begin
  p^.Key.Free;
end;

procedure TGCustomObjectHashSet.DoClear;
var
  e: PEntry;
begin
  if OwnsObjects then
    for e in FTable do
      e^.Key.Free;
  inherited;
end;

function TGCustomObjectHashSet.DoRemove(const aValue: T): Boolean;
begin
  Result := inherited DoRemove(aValue);
  if Result and OwnsObjects then
    aValue.Free;
end;

function TGCustomObjectHashSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

function TGCustomObjectHashSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

function TGCustomObjectHashSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

constructor TGCustomObjectHashSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashSet.CreateCopy(aSet: TGCustomObjectHashSet);
begin
  inherited CreateCopy(aSet);
  OwnsObjects := aSet.OwnsObjects;
end;

{ TGObjectHashSetLP }

class function TGObjectHashSetLP.GetClass: THashSetClass;
begin
  Result := TGObjectHashSetLP;
end;

class function TGObjectHashSetLP.GetTableClass: THashTableClass;
begin
  Result := specialize TGOpenAddrLP<T, TEntry, TEqRel>;
end;

function TGObjectHashSetLP.Clone: TGObjectHashSetLP;
begin
  Result := TGObjectHashSetLP.CreateCopy(Self);
end;

{ TGObjectHashSetLPT }

function TGObjectHashSetLPT.GetTombstonesCount: SizeInt;
begin
  Result := THashTableLPT(FTable).TombstonesCount;
end;

class function TGObjectHashSetLPT.GetClass: THashSetClass;
begin
  Result := TGObjectHashSetLPT;
end;

class function TGObjectHashSetLPT.GetTableClass: THashTableClass;
begin
  Result := THashTableLPT;
end;

function TGObjectHashSetLPT.Clone: TGObjectHashSetLPT;
begin
  Result := TGObjectHashSetLPT.CreateCopy(Self);
end;

procedure TGObjectHashSetLPT.ClearTombstones;
begin
  THashTableLPT(FTable).ClearTombstones;
end;

{ TGObjectHashSetQP }

function TGObjectHashSetQP.GetTombstonesCount: SizeInt;
begin
  Result := THashTableQP(FTable).TombstonesCount;
end;

class function TGObjectHashSetQP.GetClass: THashSetClass;
begin
  Result := TGObjectHashSetQP;
end;

class function TGObjectHashSetQP.GetTableClass: THashTableClass;
begin
  Result := THashTableQP;
end;

function TGObjectHashSetQP.Clone: TGObjectHashSetQP;
begin
  Result := TGObjectHashSetQP.CreateCopy(Self);
end;

procedure TGObjectHashSetQP.ClearTombstones;
begin
  THashTableQP(FTable).ClearTombstones;
end;

{ TGObjectOrderedHashSet }

procedure TGObjectOrderedHashSet.EntryRemoving(p: PEntry);
begin
  p^.Key.Free;
end;

procedure TGObjectOrderedHashSet.DoClear;
var
  e: PEntry;
begin
  if OwnsObjects then
    for e in FTable do
      e^.Key.Free;
  inherited;
end;

function TGObjectOrderedHashSet.DoRemove(const aValue: T): Boolean;
begin
  Result := inherited DoRemove(aValue);
  if Result and OwnsObjects then
    aValue.Free;
end;

function TGObjectOrderedHashSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

function TGObjectOrderedHashSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

function TGObjectOrderedHashSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  if OwnsObjects then
    Result := FTable.RemoveIf(aTest, @EntryRemoving)
  else
    Result := FTable.RemoveIf(aTest);
end;

class function TGObjectOrderedHashSet.GetClass: THashSetClass;
begin
  Result := TGObjectOrderedHashSet;
end;

class function TGObjectOrderedHashSet.GetTableClass: THashTableClass;
begin
  Result := TOrderedHashTable;
end;

constructor TGObjectOrderedHashSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, a);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, e);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectOrderedHashSet.CreateCopy(aSet: TGObjectOrderedHashSet);
begin
  inherited CreateCopy(aSet);
  OwnsObjects := aSet.OwnsObjects;
end;

function TGObjectOrderedHashSet.Clone: TGObjectOrderedHashSet;
begin
  Result := TGObjectOrderedHashSet.CreateCopy(Self);
end;

{ TGObjectChainHashSet }

class function TGObjectChainHashSet.GetClass: THashSetClass;
begin
  Result := TGObjectChainHashSet;
end;

class function TGObjectChainHashSet.GetTableClass: THashTableClass;
begin
  Result := specialize TGChainHashTable<T, TEntry, TEqRel>;
end;

function TGObjectChainHashSet.Clone: TGObjectChainHashSet;
begin
  Result := TGObjectChainHashSet.CreateCopy(Self);
end;

{ TGLiteHashSet.TEnumerator }

function TGLiteHashSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

function TGLiteHashSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGLiteHashSet.TEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGLiteHashSet }

function TGLiteHashSet.GetCapacity: SizeInt;
begin
  Result := FTable.Capacity;
end;

function TGLiteHashSet.GetCount: SizeInt;
begin
  Result := FTable.Count;
end;

function TGLiteHashSet.GetFillRatio: Single;
begin
  Result := FTable.FillRatio;
end;

function TGLiteHashSet.GetLoadFactor: Single;
begin
  Result := FTable.LoadFactor;
end;

function TGLiteHashSet.GetExpandTreshold: SizeInt;
begin
  Result := FTable.ExpandTreshold;
end;

procedure TGLiteHashSet.SetLoadFactor(aValue: Single);
begin
  FTable.LoadFactor := aValue;
end;

function TGLiteHashSet.DefaultLoadFactor: Single;
begin
  Result := FTable.DEFAULT_LOAD_FACTOR;
end;

function TGLiteHashSet.MaxLoadFactor: Single;
begin
  Result := FTable.MAX_LOAD_FACTOR;
end;

function TGLiteHashSet.MinLoadFactor: Single;
begin
  Result := FTable.MIN_LOAD_FACTOR;
end;

function TGLiteHashSet.GetEnumerator: TEnumerator;
begin
  Result.FEnum := FTable.GetEnumerator;
end;

function TGLiteHashSet.ToArray: TArray;
var
  I: SizeInt = 0;
  e: TTblEnumerator;
begin
  System.SetLength(Result, Count);
  e := FTable.GetEnumerator;
  while e.MoveNext do
    begin
      Result[I] := e.Current^.Key;
      Inc(I);
    end;
end;

function TGLiteHashSet.IsEmpty: Boolean;
begin
  Result := FTable.Count = 0;
end;

function TGLiteHashSet.NonEmpty: Boolean;
begin
  Result := FTable.Count <> 0;
end;

procedure TGLiteHashSet.Clear;
begin
  FTable.Clear;
end;

procedure TGLiteHashSet.TrimToFit;
begin
  FTable.TrimToFit;
end;

procedure TGLiteHashSet.EnsureCapacity(aValue: SizeInt);
begin
  FTable.EnsureCapacity(aValue);
end;

function TGLiteHashSet.Add(const aValue: T): Boolean;
var
  p: PEntry;
begin
  Result := not FTable.FindOrAdd(aValue, p);
  if Result then
    p^.Key := aValue;
end;

function TGLiteHashSet.AddAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    Add(a[I]);
  Result := Count - Result;
end;

function TGLiteHashSet.AddAll(e: IEnumerable): SizeInt;
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

function TGLiteHashSet.AddAll(constref aSet: TGLiteHashSet): SizeInt;
var
  v: T;
begin
  if @aSet <> @Self then
    begin
      Result := Count;
      for v in aSet do
        Add(v);
      Result := Count - Result;
    end
  else
    Result := 0;
end;

function TGLiteHashSet.Contains(const aValue: T): Boolean;
begin
  Result := FTable.Find(aValue) <> nil;
end;

function TGLiteHashSet.NonContains(const aValue: T): Boolean;
begin
  Result := FTable.Find(aValue) = nil;
end;

function TGLiteHashSet.FindFirst(out aValue: T): Boolean;
begin
  Result := FTable.FindFirstKey(aValue);
end;

function TGLiteHashSet.ContainsAny(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if NonEmpty then
    for I := 0 to System.High(a) do
      if FTable.Find(a[I]) <> nil then
        exit(True);
  Result := False;
end;

function TGLiteHashSet.ContainsAny(e: IEnumerable): Boolean;
begin
  if NonEmpty then
    with e.GetEnumerator do
      try
        while MoveNext do
          if FTable.Find(Current) <> nil then
            exit(True);
      finally
        Free;
      end
  else
    e.Discard;
  Result := False;
end;

function TGLiteHashSet.ContainsAny(constref aSet: TGLiteHashSet): Boolean;
begin
  if @aSet = @Self then
    exit(True);
  if NonEmpty then
    with aSet.GetEnumerator do
      while MoveNext do
        if FTable.Find(Current) <> nil then
          exit(True);
  Result := False;
end;

function TGLiteHashSet.ContainsAll(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if IsEmpty then exit(System.Length(a) = 0);
  for I := 0 to System.High(a) do
    if FTable.Find(a[I]) = nil then
      exit(False);
  Result := True;
end;

function TGLiteHashSet.ContainsAll(e: IEnumerable): Boolean;
begin
  if IsEmpty then exit(e.None);
  with e.GetEnumerator do
    try
      while MoveNext do
        if FTable.Find(Current) = nil then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGLiteHashSet.ContainsAll(constref aSet: TGLiteHashSet): Boolean;
begin
  if @aSet = @Self then
    exit(True);
  if IsEmpty then exit(aSet.IsEmpty);
  with aSet.GetEnumerator do
    while MoveNext do
      if FTable.Find(Current) = nil then
        exit(False);
  Result := True;
end;

function TGLiteHashSet.Remove(const aValue: T): Boolean;
begin
  Result := FTable.Remove(aValue);
end;

function TGLiteHashSet.RemoveAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if FTable.Remove(a[I]) and (FTable.Count = 0) then
          break;
      Result -= Count;
    end;
end;

function TGLiteHashSet.RemoveAll(e: IEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if FTable.Remove(Current) and (FTable.Count = 0) then
              break;
        finally
          Free;
        end;
      Result -= Count;
    end
  else
    e.Discard;
end;

function TGLiteHashSet.RemoveAll(constref aSet: TGLiteHashSet): SizeInt;
begin
  if @aSet <> @Self then
    begin
      Result := Count;
      begin
        with aSet.GetEnumerator do
          while MoveNext do
            if FTable.Remove(Current) and (FTable.Count = 0) then
              break;
        Result -= Count;
      end;
    end
  else
    begin
      Result := Count;
      Clear;
    end;
end;

function TGLiteHashSet.RemoveIf(aTest: TTest): SizeInt;
var
  re: TTblRemovableEnumerator;
begin
  re := FTable.GetRemovableEnumerator;
  Result := Count;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      re.RemoveCurrent;
  Result -= Count;
end;

function TGLiteHashSet.RemoveIf(aTest: TOnTest): SizeInt;
var
  re: TTblRemovableEnumerator;
begin
  re := FTable.GetRemovableEnumerator;
  Result := Count;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      re.RemoveCurrent;
  Result -= Count;
end;

function TGLiteHashSet.RemoveIf(aTest: TNestTest): SizeInt;
var
  re: TTblRemovableEnumerator;
begin
  re := FTable.GetRemovableEnumerator;
  Result := Count;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      re.RemoveCurrent;
  Result -= Count;
end;

function TGLiteHashSet.Extract(const aValue: T): Boolean;
begin
  Result := FTable.Remove(aValue);
end;

function TGLiteHashSet.ExtractIf(aTest: TTest): TArray;
var
  re: TTblRemovableEnumerator;
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  re := FTable.GetRemovableEnumerator;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I shl 1);
        Result[I] := re.Current^.Key;
        re.RemoveCurrent;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

function TGLiteHashSet.ExtractIf(aTest: TOnTest): TArray;
var
  re: TTblRemovableEnumerator;
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  re := FTable.GetRemovableEnumerator;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I shl 1);
        Result[I] := re.Current^.Key;
        re.RemoveCurrent;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

function TGLiteHashSet.ExtractIf(aTest: TNestTest): TArray;
var
  re: TTblRemovableEnumerator;
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  re := FTable.GetRemovableEnumerator;
  while re.MoveNext do
    if aTest(re.Current^.Key) then
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I shl 1);
        Result[I] := re.Current^.Key;
        re.RemoveCurrent;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

procedure TGLiteHashSet.RetainAll(aCollection: ICollection);
var
  re: TTblRemovableEnumerator;
begin
  re := FTable.GetRemovableEnumerator;
  while re.MoveNext do
    if aCollection.NonContains(re.Current^.Key) then
      re.RemoveCurrent;
end;

procedure TGLiteHashSet.RetainAll(constref aSet: TGLiteHashSet);
var
  re: TTblRemovableEnumerator;
begin
  if @aSet <> @Self then
    begin
      re := FTable.GetRemovableEnumerator;
      while re.MoveNext do
        if aSet.NonContains(re.Current^.Key) then
          re.RemoveCurrent;
    end;
end;

function TGLiteHashSet.IsSuperset(constref aSet: TGLiteHashSet): Boolean;
begin
  Result := ContainsAll(aSet);
end;

function TGLiteHashSet.IsSubset(constref aSet: TGLiteHashSet): Boolean;
begin
  Result := aSet.ContainsAll(Self);
end;

function TGLiteHashSet.IsEqual(constref aSet: TGLiteHashSet): Boolean;
begin
  if @aSet <> @Self then
    begin
      if Count <> aSet.Count then
        exit(False);
      Result := ContainsAll(aSet);
    end
  else
    Result := True;
end;

function TGLiteHashSet.Intersecting(constref aSet: TGLiteHashSet): Boolean;
begin
  if @aSet <> @Self then
    Result := ContainsAny(aSet)
  else
    Result := True;
end;

procedure TGLiteHashSet.Intersect(constref aSet: TGLiteHashSet);
begin
  RetainAll(aSet);
end;

procedure TGLiteHashSet.Join(constref aSet: TGLiteHashSet);
begin
  if @aSet <> @Self then
    with aSet.GetEnumerator do
      while MoveNext do
        Add(Current);
end;

procedure TGLiteHashSet.Subtract(constref aSet: TGLiteHashSet);
begin
  if @aSet <> @Self then
    with aSet.GetEnumerator do
      while MoveNext do
        Remove(Current)
  else
    Clear;
end;

procedure TGLiteHashSet.SymmetricSubtract(constref aSet: TGLiteHashSet);
var
  v: T;
  e: PEntry;
  Pos: SizeInt;
begin
  if @aSet <> @Self then
    begin
      for v in aSet do
        if FTable.FindOrAdd(v, e, Pos) then
          FTable.RemoveAt(Pos)
        else
          e^.Key := v;
    end
  else
    Clear;
end;

class operator TGLiteHashSet. + (constref L, R: TGLiteHashSet): TGLiteHashSet;
begin
  Result := L;
  Result.Join(R);
end;

class operator TGLiteHashSet. - (constref L, R: TGLiteHashSet): TGLiteHashSet;
begin
  Result := L;
  Result.Subtract(R);
end;

class operator TGLiteHashSet. * (constref L, R: TGLiteHashSet): TGLiteHashSet;
begin
  Result := L;
  Result.Intersect(R);
end;

class operator TGLiteHashSet.><(constref L, R: TGLiteHashSet): TGLiteHashSet;
begin
  Result := L;
  Result.SymmetricSubtract(R);
end;

class operator TGLiteHashSet.in(constref aValue: T; constref aSet: TGLiteHashSet): Boolean;
begin
  Result := aSet.Contains(aValue);
end;

class operator TGLiteHashSet. = (constref L, R: TGLiteHashSet): Boolean;
begin
  Result := L.IsEqual(R);
end;

class operator TGLiteHashSet.<=(constref L, R: TGLiteHashSet): Boolean;
begin
  Result := L.IsSubset(R);
end;

{ TGDisjointSetUnion.TEnumerator }

function TGDisjointSetUnion.TEnumerator.GetCurrent: T;
begin
  Result := FList[FCurrIndex].Data.Key;
end;

function TGDisjointSetUnion.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLastIndex;
  FCurrIndex += Ord(Result);
end;

procedure TGDisjointSetUnion.TEnumerator.Reset;
begin
  FCurrIndex := -1;
end;

{ TGDisjointSetUnion }

function TGDisjointSetUnion.GetCapacity: SizeInt;
begin
  Result := FTable.Capacity;
end;

function TGDisjointSetUnion.GetCount: SizeInt;
begin
  Result := FTable.Count;
end;

function TGDisjointSetUnion.FindOrAdd(const aValue: T): SizeInt;
var
  OldCapacity: SizeInt;
  e: PEntry;
begin
  OldCapacity := Capacity;
  if not FTable.FindOrAdd(aValue, e, Result) then
    begin
      e^.Key := aValue;
      if Capacity > OldCapacity then
        ExpandDsu;
    end;
end;

function TGDisjointSetUnion.GetEnumerator: TEnumerator;
begin
  Result.FList := FTable.NodeList;
  Result.FLastIndex := Pred(FTable.Count);
  Result.FCurrIndex := -1;
end;

function TGDisjointSetUnion.ToArray: TArray;
var
  v: T;
  I: SizeInt = 0;
begin
  System.SetLength(Result, Count);
  for v in Self do
    begin
      Result[I] := v;
      Inc(I);
    end;
end;

function TGDisjointSetUnion.IsEmpty: Boolean;
begin
  Result := FTable.Count = 0;
end;

function TGDisjointSetUnion.NonEmpty: Boolean;
begin
  Result := FTable.Count <> 0;
end;

procedure TGDisjointSetUnion.Clear;
begin
  FTable.Clear;
  FDsu := nil;
end;

procedure TGDisjointSetUnion.ExpandDsu;
var
  I, NewCapacity: SizeInt;
begin
  I := System.Length(FDsu);
  NewCapacity := Capacity;
  System.SetLength(FDsu, NewCapacity);
  for I := I to Pred(NewCapacity) do
    FDsu[I] := I;
end;

function TGDisjointSetUnion.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FTable.NodeList[aIndex].Data.Key
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGDisjointSetUnion.GetTag(aValue: SizeInt): SizeInt;
begin
  if FDsu[aValue] = aValue then
    exit(aValue);
  Result := GetTag(FDsu[aValue]);
  FDsu[aValue] := Result;
end;

procedure TGDisjointSetUnion.EnsureCapacity(aValue: SizeInt);
var
  OldCapacity: SizeInt;
begin
  OldCapacity := Capacity;
  FTable.EnsureCapacity(aValue);
  if Capacity > OldCapacity then
    ExpandDsu;
end;

function TGDisjointSetUnion.IndexOf(const aValue: T): SizeInt;
begin
  FTable.Find(aValue, Result);
end;

function TGDisjointSetUnion.Contains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) >= 0;
end;

function TGDisjointSetUnion.NonContains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) < 0;
end;

function TGDisjointSetUnion.Add(const aValue: T): SizeInt;
var
  OldCapacity: SizeInt;
  e: PEntry;
begin
  OldCapacity := Capacity;
  if not FTable.FindOrAdd(aValue, e, Result) then
    begin
      e^.Key := aValue;
      if Capacity > OldCapacity then
        ExpandDsu;
    end
  else
    Result := -1;
end;

procedure TGDisjointSetUnion.Reset;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FDsu) do
    FDsu[I] := I;
end;

function TGDisjointSetUnion.Tag(const aValue: T): SizeInt;
var
  I: SizeInt;
begin
  I := FindOrAdd(aValue);
  Result := GetTag(I);
end;

function TGDisjointSetUnion.TagI(aIndex: SizeInt): SizeInt;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := GetTag(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGDisjointSetUnion.InSameSet(const L, R: T): Boolean;
var
  I, J: SizeInt;
begin
  I := FindOrAdd(L);
  J := FindOrAdd(R);
  Result := GetTag(I) = GetTag(J);
end;

function TGDisjointSetUnion.InSameSetI(L, R: SizeInt): Boolean;
begin
  Result := TagI(L) = TagI(R);
end;

function TGDisjointSetUnion.InDiffSets(const L, R: T): Boolean;
var
  I, J: SizeInt;
begin
  I := FindOrAdd(L);
  J := FindOrAdd(R);
  Result := GetTag(I) <> GetTag(J);
end;

function TGDisjointSetUnion.InDiffSetsI(L, R: SizeInt): Boolean;
begin
  Result := TagI(L) <> TagI(R);
end;

function TGDisjointSetUnion.Join(const L, R: T): Boolean;
var
  I, J: SizeInt;
begin
  I := GetTag(FindOrAdd(L));
  J := GetTag(FindOrAdd(R));
  if I = J then
    exit(False);
  if NextRandomBoolean then
    FDsu[I] := J
  else
    FDsu[J] := I;
  Result := True;
end;

function TGDisjointSetUnion.JoinI(L, R: SizeInt): Boolean;
begin
  L := TagI(L);
  R := TagI(R);
  if L = R then
    exit(False);
  if NextRandomBoolean then
    FDsu[L] := R
  else
    FDsu[R] := L;
  Result := True;
end;

{ TGThreadFGHashSet.TSlot }

class operator TGThreadFGHashSet.TSlot.Initialize(var aSlot: TSlot);
begin
  aSlot.FState := 0;
  aSlot.Head := nil;
end;

procedure TGThreadFGHashSet.TSlot.Lock;
begin
{$IFDEF CPU64}
  while Boolean(InterlockedExchange64(FState, SizeUInt(1))) do
{$ELSE CPU64}
  while Boolean(InterlockedExchange(FState, SizeUInt(1))) do
{$ENDIF CPU64}
    ThreadSwitch;
end;

procedure TGThreadFGHashSet.TSlot.Unlock;
begin
{$IFDEF CPU64}
  InterlockedExchange64(FState, SizeUInt(0));
{$ELSE CPU64}
  InterlockedExchange(FState, SizeUInt(0));
{$ENDIF CPU64}
end;

{ TGThreadFGHashSet }

function TGThreadFGHashSet.NewNode(const aValue: T; aHash: SizeInt): PNode;
begin
  New(Result);
  Result^.Hash := aHash;
  Result^.Value := aValue;
{$IFDEF CPU64}
  InterlockedIncrement64(FCount);
{$ELSE CPU64}
  InterlockedIncrement(FCount);
{$ENDIF CPU64}
end;

procedure TGThreadFGHashSet.FreeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Value := Default(T);
      Dispose(aNode);
    {$IFDEF CPU64}
      InterlockedDecrement64(FCount);
    {$ELSE CPU64}
      InterlockedDecrement(FCount);
    {$ENDIF CPU64}
    end;
end;

function TGThreadFGHashSet.GetCapacity: SizeInt;
begin
  FGlobLock.BeginRead;
  try
    Result := System.Length(FSlotList);
  finally
    FGlobLock.EndRead;
  end;
end;

procedure TGThreadFGHashSet.ClearChainList;
var
  Node, Next: PNode;
  I: SizeInt;
begin
  for I := 0 to System.High(FSlotList) do
    begin
      Node := FSlotList[I].Head;
      while Node <> nil do
        begin
          Next := Node^.Next;
          Node^.Value := Default(T);
          Dispose(Node);
          Node := Next;
        end;
    end;
  FSlotList := nil;
end;

function TGThreadFGHashSet.LockSlot(const aValue: T; out aHash: SizeInt): SizeInt;
begin
  aHash := TEqRel.HashCode(aValue);
  FGlobLock.BeginRead;
  try
    Result := aHash and System.High(FSlotList);
    FSlotList[Result].Lock;
  finally
    FGlobLock.EndRead;
  end;
end;

function TGThreadFGHashSet.Find(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
var
  Node: PNode;
begin
  Node := FSlotList[aSlotIdx].Head;
  while Node <> nil do
    begin
      if (Node^.Hash = aHash) and TEqRel.Equal(Node^.Value, aValue) then
        exit(Node);
      Node := Node^.Next;
    end;
  Result := nil;
end;

function TGThreadFGHashSet.RemoveNode(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
var
  Node: PNode;
  Prev: PNode = nil;
begin
  Node := FSlotList[aSlotIdx].Head;
  while Node <> nil do
    begin
      if (Node^.Hash = aHash) and TEqRel.Equal(Node^.Value, aValue) then
        begin
          if Prev <> nil then
            Prev^.Next := Node^.Next
          else
            FSlotList[aSlotIdx].Head := Node^.Next;
          exit(Node);
        end;
      Prev := Node;
      Node := Node^.Next;
    end;
  Result := nil;
end;

procedure TGThreadFGHashSet.CheckNeedExpand;
begin
  if Count > Succ(Trunc(System.Length(FSlotList) * FLoadFactor)) then
    begin
      FGlobLock.BeginWrite;
      try
        if Count > Succ(Trunc(System.Length(FSlotList) * FLoadFactor)) then
          Expand;
      finally
        FGlobLock.EndWrite;
      end;
    end;
end;

procedure TGThreadFGHashSet.Expand;
var
  I, Len, Mask: SizeInt;
  Node, Next: PNode;
  Head: PNode = nil;
begin
  Len := System.Length(FSlotList);
  for I := 0 to Pred(Len) do
    FSlotList[I].Lock;
  try
    for I := 0 to Pred(Len) do
      begin
        Node := FSlotList[I].Head;
        while Node <> nil do
          begin
            Next := Node^.Next;
            Node^.Next := Head;
            Head := Node;
            Node := Next;
          end;
        FSlotList[I].Head := nil;
      end;
     Mask := Pred(Len * 2);
     System.SetLength(FSlotList, Succ(Mask));
     Node := Head;
     while Node <> nil do
       begin
         I := Node^.Hash and Mask;
         Next := Node^.Next;
         Node^.Next := FSlotList[I].Head;
         FSlotList[I].Head := Node;
         Node := Next;
       end;
  finally
    for I := Pred(Len) downto 0 do
      FSlotList[I].Unlock;
  end;
end;

constructor TGThreadFGHashSet.Create;
begin
  FLoadFactor := DEFAULT_LOAD_FACTOR;
  System.SetLength(FSlotList, DEFAULT_CONTAINER_CAPACITY);
  FGlobLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

constructor TGThreadFGHashSet.Create(aCapacity: SizeInt; aLoadFactor: Single);
var
  RealCap: SizeInt;
begin
  if aLoadFactor < MIN_LOAD_FACTOR then
    aLoadFactor := MIN_LOAD_FACTOR
  else
    if aLoadFactor > MAX_LOAD_FACTOR then
      aLoadFactor := MAX_LOAD_FACTOR;
  FLoadFactor := aLoadFactor;
  if aCapacity < DEFAULT_CONTAINER_CAPACITY then
    aCapacity := DEFAULT_CONTAINER_CAPACITY;
  RealCap := RoundUpTwoPower(aCapacity);
  System.SetLength(FSlotList, RealCap);
  FGlobLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

destructor TGThreadFGHashSet.Destroy;
begin
  FGlobLock.BeginWrite;
  try
    ClearChainList;
    inherited;
  finally
    FGlobLock.EndWrite;
    FGlobLock.Free;
  end;
end;

function TGThreadFGHashSet.Add(const aValue: T): Boolean;
var
  SlotIdx, Hash: SizeInt;
  Node: PNode;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Node := Find(aValue, SlotIdx, Hash);
    Result := Node = nil;
    if Result then
      begin
        Node := NewNode(aValue, Hash);
        Node^.Next := FSlotList[SlotIdx].Head;
        FSlotList[SlotIdx].Head := Node;
      end;
  finally
    FSlotList[SlotIdx].Unlock;
  end;
  if Result then
    CheckNeedExpand;
end;

function TGThreadFGHashSet.Contains(const aValue: T): Boolean;
var
  SlotIdx, Hash: SizeInt;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Result := Find(aValue, SlotIdx, Hash) <> nil;
  finally
    FSlotList[SlotIdx].Unlock;
  end;
end;

function TGThreadFGHashSet.Remove(const aValue: T): Boolean;
var
  SlotIdx, Hash: SizeInt;
  Node: PNode;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Node := RemoveNode(aValue, SlotIdx, Hash);
    Result := Node <> nil;
    if Result then
      FreeNode(Node);
  finally
    FSlotList[SlotIdx].Unlock;
  end;
end;

end.

