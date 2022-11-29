{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Common abstact container classes.                                       *
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
unit lgAbstractContainer;

{$MODE OBJFPC}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses

  SysUtils,
  math,
  lgUtils,
  {%H-}lgHelpers,
  lgArrayHelpers,
  lgStrConst;

type

  { TGEnumerable }

  generic TGEnumerable<T> = class abstract(TObject, specialize IGEnumerable<T>, IObjInstance)
  public
  type
    TSpecEnumerator = specialize TGEnumerator<T>;
    IEnumerable     = specialize IGEnumerable<T>;
    TOptional       = specialize TGOptional<T>;
    TArray          = specialize TGArray<T>;
    TLess           = specialize TGLessCompare<T>;
    TOnLess         = specialize TGOnLessCompare<T>;
    TNestLess       = specialize TGNestLessCompare<T>;
    TTest           = specialize TGTest<T>;
    TOnTest         = specialize TGOnTest<T>;
    TNestTest       = specialize TGNestTest<T>;
    TMapFunc        = specialize TGMapFunc<T, T>;
    TOnMap          = specialize TGOnMap<T, T>;
    TNestMap        = specialize TGNestMap<T, T>;
    TUnaryProc      = specialize TGUnaryProc<T>;
    TUnaryMethod    = specialize TGUnaryMethod<T>;
    TNestUnaryProc  = specialize TGNestUnaryProc<T>;
    TFold           = specialize TGFold<T, T>;
    TOnFold         = specialize TGOnFold<T, T>;
    TNestFold       = specialize TGNestFold<T, T>;
    TDefaults       = specialize TGDefaults<T>;
    TItem           = T;
    PItem           = ^T;
  protected
    function  _GetRef: TObject; inline;
    procedure Discard;
  public
    function  GetEnumerator: TSpecEnumerator; virtual; abstract;
  { enumerates elements in reverse order }
    function  Reverse: IEnumerable; virtual;
    function  ToArray: TArray; virtual;
    function  Any: Boolean;
    function  None: Boolean;
    function  Total: SizeInt;
    function  FindFirst(out aValue: T): Boolean;
    function  First: TOptional;
    function  FindLast(out aValue: T): Boolean;
    function  Last: TOptional;
    function  FindMin(out aValue: T; c: TLess): Boolean;
    function  FindMin(out aValue: T; c: TOnLess): Boolean;
    function  FindMin(out aValue: T; c: TNestLess): Boolean;
    function  Min(c: TLess): TOptional;
    function  Min(c: TOnLess): TOptional;
    function  Min(c: TNestLess): TOptional;
    function  FindMax(out aValue: T; c: TLess): Boolean;
    function  FindMax(out aValue: T; c: TOnLess): Boolean;
    function  FindMax(out aValue: T; c: TNestLess): Boolean;
    function  Max(c: TLess): TOptional;
    function  Max(c: TOnLess): TOptional;
    function  Max(c: TNestLess): TOptional;
    function  Skip(aCount: SizeInt): IEnumerable; inline;
    function  SkipWhile(aTest: TTest): IEnumerable; inline;
    function  SkipWhile(aTest: TOnTest): IEnumerable; inline;
    function  SkipWhile(aTest: TNestTest): IEnumerable; inline;
    function  Limit(aCount: SizeInt): IEnumerable; inline;
    function  TakeWhile(aTest: TTest): IEnumerable; inline;
    function  TakeWhile(aTest: TOnTest): IEnumerable; inline;
    function  TakeWhile(aTest: TNestTest): IEnumerable; inline;
    function  Sorted(c: TLess; aStable: Boolean = False): IEnumerable;
    function  Sorted(c: TOnLess; aStable: Boolean = False): IEnumerable;
    function  Sorted(c: TNestLess; aStable: Boolean = False): IEnumerable;
    function  Sorted(aSort: specialize TGSortProc<T>; o: TSortOrder = soAsc): IEnumerable;
    function  Select(aTest: TTest): IEnumerable; inline;
    function  Select(aTest: TOnTest): IEnumerable; inline;
    function  Select(aTest: TNestTest): IEnumerable; inline;
    function  Any(aTest: TTest): Boolean;
    function  Any(aTest: TOnTest): Boolean;
    function  Any(aTest: TNestTest): Boolean;
    function  None(aTest: TTest): Boolean; inline;
    function  None(aTest: TOnTest): Boolean; inline;
    function  None(aTest: TNestTest): Boolean; inline;
    function  All(aTest: TTest): Boolean;
    function  All(aTest: TOnTest): Boolean;
    function  All(aTest: TNestTest): Boolean;
    function  Total(aTest: TTest): SizeInt;
    function  Total(aTest: TOnTest): SizeInt;
    function  Total(aTest: TNestTest): SizeInt;
    function  Distinct(c: TLess): IEnumerable;
    function  Distinct(c: TOnLess): IEnumerable;
    function  Distinct(c: TNestLess): IEnumerable;
    function  Map(aMap: TMapFunc): IEnumerable; inline;
    function  Map(aMap: TOnMap): IEnumerable; inline;
    function  Map(aMap: TNestMap): IEnumerable; inline;
    procedure ForEach(aCallback: TUnaryProc);
    procedure ForEach(aCallback: TUnaryMethod);
    procedure ForEach(aCallback: TNestUnaryProc);
  { left-associative linear fold }
    function  Fold(aFold: TFold; const aInitVal: T): T;
  { result is assigned only if the instance is not empty; uses Default(T) as the initial value }
    function  Fold(aFold: TFold): TOptional;
    function  Fold(aFold: TOnFold; const aInitVal: T): T;
  { result is assigned only if the instance is not empty; uses Default(T) as the initial value }
    function  Fold(aFold: TOnFold): TOptional;
    function  Fold(aFold: TNestFold; const aInitVal: T): T;
  {result is assigned only if the instance is not empty; uses Default(T) as the initial value }
    function  Fold(aFold: TNestFold): TOptional;
  end;

{$I EnumsH.inc}

  { TGAbstractContainer: container abstract ancestor class }
  generic TGAbstractContainer<T> = class abstract(specialize TGEnumerable<T>, specialize IGContainer<T>)
  public
  type
    TSpecContainer = specialize TGAbstractContainer<T>;

  protected
  type
    //to supress unnecessary refcounting
    TFake = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};
    TFakeArray = array of TFake;

    TContainerEnumerator = class(specialize TGEnumerator<T>)
    strict protected
      FOwner: TSpecContainer;
    public
      constructor Create(c: TSpecContainer);
      destructor Destroy; override;
    end;

    TContainerEnumerable = class(specialize TGAutoEnumerable<T>)
    strict protected
      FOwner: TSpecContainer;
    public
      constructor Create(c: TSpecContainer);
      destructor Destroy; override;
    end;

  strict private
    FItCounter: Integer;
    function  GetInIteration: Boolean; inline;
  protected
    procedure CapacityExceedError(aValue: SizeInt);
    procedure AccessEmptyError;
    procedure IndexOutOfBoundError(aIndex: SizeInt);
    procedure UpdateLockError;
    procedure CheckInIteration; inline;
    procedure BeginIteration;
    procedure EndIteration;
    function  GetCount: SizeInt; virtual; abstract;
    function  GetCapacity: SizeInt; virtual; abstract;
    function  DoGetEnumerator: TSpecEnumerator;  virtual; abstract;
    procedure DoClear; virtual; abstract;
    procedure DoTrimToFit; virtual; abstract;
    procedure DoEnsureCapacity(aValue: SizeInt); virtual; abstract;
    procedure CopyItems(aBuffer: PItem); virtual;
    property  InIteration: Boolean read GetInIteration;
  public
    function  GetEnumerator: TSpecEnumerator; override;
    function  ToArray: TArray; override;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear;
    procedure TrimToFit;
    procedure EnsureCapacity(aValue: SizeInt);
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

{$I DynBufferH.inc}

  { TGAbstractCollection: collection abstract ancestor class}
  generic TGAbstractCollection<T> = class abstract(specialize TGAbstractContainer<T>, specialize IGCollection<T>,
    specialize IGReadOnlyCollection<T>)
  public
  type
    TSpecCollection = specialize TGAbstractCollection<T>;
    ICollection     = specialize IGCollection<T>;

  protected
    function  DoAdd(const aValue: T): Boolean; virtual; abstract;
    function  DoExtract(const aValue: T): Boolean; virtual; abstract;
    function  DoRemoveIf(aTest: TTest): SizeInt; virtual; abstract;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; virtual; abstract;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; virtual; abstract;
    function  DoExtractIf(aTest: TTest): TArray; virtual; abstract;
    function  DoExtractIf(aTest: TOnTest): TArray; virtual; abstract;
    function  DoExtractIf(aTest: TNestTest): TArray; virtual; abstract;

    function  DoRemove(const aValue: T): Boolean; virtual;
    function  DoAddAll(const a: array of T): SizeInt; virtual; overload;
    function  DoAddAll(e: IEnumerable): SizeInt; virtual; abstract; overload;
    function  DoRemoveAll(const a: array of T): SizeInt;
    function  DoRemoveAll(e: IEnumerable): SizeInt; virtual;
  public
  { returns True if element added }
    function  Add(const aValue: T): Boolean;
  { returns count of added elements }
    function  AddAll(const a: array of T): SizeInt;
  { returns count of added elements }
    function  AddAll(e: IEnumerable): SizeInt;
    function  Contains(const aValue: T): Boolean; virtual; abstract;
    function  NonContains(const aValue: T): Boolean;
    function  ContainsAny(const a: array of T): Boolean;
    function  ContainsAny(e: IEnumerable): Boolean;
    function  ContainsAll(const a: array of T): Boolean;
    function  ContainsAll(e: IEnumerable): Boolean;
  { returns True if element removed }
    function  Remove(const aValue: T): Boolean;
  { returns count of removed elements }
    function  RemoveAll(const a: array of T): SizeInt;
  { returns count of removed elements }
    function  RemoveAll(e: IEnumerable): SizeInt;
  { returns count of removed elements }
    function  RemoveIf(aTest: TTest): SizeInt;
    function  RemoveIf(aTest: TOnTest): SizeInt;
    function  RemoveIf(aTest: TNestTest): SizeInt;
  { returns True if element extracted }
    function  Extract(const aValue: T): Boolean;
    function  ExtractIf(aTest: TTest): TArray;
    function  ExtractIf(aTest: TOnTest): TArray;
    function  ExtractIf(aTest: TNestTest): TArray;
  { will contain only those elements that are simultaneously contained in self and aCollection }
    procedure RetainAll(aCollection: ICollection);
    function  Clone: TSpecCollection; virtual; abstract;
  end;

  { TGThreadCollection: mutex based concurrent collection }
  generic TGThreadCollection<T> = class
  public
  type
    ICollection = specialize IGCollection<T>;

  private
    FCollection: ICollection;
    FLock: TRTLCriticalSection;
    FOwnsColl: Boolean;
  protected
    procedure Lock; inline;
  public
    constructor Create(aCollection: ICollection; aOwnsCollection: Boolean = True);
    destructor Destroy; override;
    function  LockCollection: ICollection;
    procedure Unlock; inline;
    procedure Clear;
    function  Contains(const aValue: T): Boolean;
    function  Add(const aValue: T): Boolean;
    function  Remove(const aValue: T): Boolean;
    property  OwnsCollection: Boolean read FOwnsColl;
  end;

  { TGThreadRWCollection: RWLock based concurrent collection }
  generic TGThreadRWCollection<T> = class
  public
  type
    ICollection = specialize IGCollection<T>;

  private
  type
    TCollection = specialize TGAbstractCollection<T>;

  var
    FCollection: ICollection;
    FRWLock: TMultiReadExclusiveWriteSynchronizer;
    FOwnsColl: Boolean;
    function GetCapacity: SizeInt;
    function GetCount: SizeInt;
  protected
    procedure BeginRead; inline;
    procedure BeginWrite; inline;
  public
  type
    IRoCollection = specialize IGReadOnlyCollection<T>;

    constructor Create(aCollection: ICollection; aOwnsCollection: Boolean = True);
    destructor Destroy; override;
    function  ReadCollection: IRoCollection;
    procedure EndRead; inline;
    function  WriteCollection: ICollection;
    procedure EndWrite; inline;
    function  Contains(const aValue: T): Boolean;
    function  Add(const aValue: T): Boolean;
    function  Remove(const aValue: T): Boolean;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  OwnsCollection: Boolean read FOwnsColl;
  end;

  { TGAbstractSet: set abstract ancestor class }
  generic TGAbstractSet<T> = class abstract(specialize TGAbstractCollection<T>)
  public
  type
    TSpecSet = specialize TGAbstractSet<T>;

  protected
  type
    TEntry = record
      Key: T;
    end;
    PEntry = ^TEntry;

    TExtractHelper = object
    private
      FCurrIndex: SizeInt;
      FExtracted: TArray;
    public
      procedure OnExtract(p: PEntry);
      procedure Init;
      function  Final: TArray;
    end;

    function  DoAddAll(e: IEnumerable): SizeInt; override; overload;
    procedure DoSymmetricSubtract(aSet: TSpecSet);
  public
    function  IsSuperset(aSet: TSpecSet): Boolean;
    function  IsSubset(aSet: TSpecSet): Boolean; inline;
    function  IsEqual(aSet: TSpecSet): Boolean;
    function  Intersecting(aSet: TSpecSet): Boolean; inline;
    procedure Intersect(aSet: TSpecSet);
    procedure Join(aSet: TSpecSet);
    procedure Subtract(aSet: TSpecSet);
    procedure SymmetricSubtract(aSet: TSpecSet);
  end;

  { TGAbstractMultiSet: multiSet abstract ancestor class  }
  generic TGAbstractMultiSet<T> = class abstract(specialize TGAbstractCollection<T>)
  public
  type
    TEntry           = specialize TGMultiSetEntry<T>;
    TSpecMultiSet    = specialize TGAbstractMultiSet<T>;
    IEntryEnumerable = specialize IGEnumerable<TEntry>;

  protected
  type
    PEntry = ^TEntry;

    TExtractHelper = object
    private
      FCurrIndex: SizeInt;
      FExtracted: TArray;
    public
      procedure OnExtract(p: PEntry);
      procedure Init;
      function  Final: TArray;
    end;

    TIntersectHelper = object
      FSet,
      FOtherSet: TSpecMultiSet;
      function OnIntersect(p: PEntry): Boolean;
    end;

  var
    FCount: SizeInt;
    function  FindEntry(const aKey: T): PEntry; virtual; abstract;
    //return True if aKey found, otherwise inserts entry (garbage) and return False;
    function  FindOrAdd(const aKey: T; out p: PEntry): Boolean; virtual; abstract;
    //returns True only if e removed
    function  DoSubEntry(const e: TEntry): Boolean; virtual; abstract;
    //returns True only if e removed
    function  DoSymmSubEntry(const e: TEntry): Boolean; virtual; abstract;
    function  GetEntryCount: SizeInt; virtual; abstract;
    function  DoDoubleEntryCounters: SizeInt; virtual; abstract;
    function  GetDistinct: IEnumerable; virtual; abstract;  // distinct keys
    function  GetEntries: IEntryEnumerable; virtual; abstract;
    procedure DoIntersect(aSet: TSpecMultiSet); virtual; abstract;

    function  GetCount: SizeInt; override;
    procedure DoJoinEntry(const e: TEntry);
    procedure DoAddEntry(const e: TEntry);
    function  GetKeyCount(const aKey: T): SizeInt;
    procedure SetKeyCount(const aKey: T; aValue: SizeInt);
    procedure DoArithAdd(aSet: TSpecMultiSet);
    procedure DoArithSubtract(aSet: TSpecMultiSet);
    procedure DoSymmSubtract(aSet: TSpecMultiSet);

    function  DoAdd(const aKey: T): Boolean; override;
    function  DoAddAll(e: IEnumerable): SizeInt; override; overload;
    function  DoRemoveAll(e: IEnumerable): SizeInt; override;
    property  ElemCount: SizeInt read FCount;
  public
    function  Contains(const aValue: T): Boolean; override;
  { returns True if multiplicity of an any key in self is greater then or equal to
    the multiplicity of that key in aSet }
    function  IsSuperSet(aSet: TSpecMultiSet): Boolean;
  { returns True if multiplicity of an any key in aSet is greater then or equal to
    the multiplicity of that key in self }
    function  IsSubSet(aSet: TSpecMultiSet): Boolean;
  { returns True if the multiplicity of an any key in self is equal to the multiplicity of that key in aSet }
    function  IsEqual(aSet: TSpecMultiSet): Boolean;
    function  Intersecting(aSet: TSpecMultiSet): Boolean;
  { will contain only those keys that are simultaneously contained in self and in aSet;
    the multiplicity of a key becomes equal to the MINIMUM of the multiplicities of a key in self and aSet }
    procedure Intersect(aSet: TSpecMultiSet);
  { will contain all keys that are contained in self or in aSet;
    the multiplicity of a key will become equal to the MAXIMUM of the multiplicities of
    a key in self and aSet }
    procedure Join(aSet: TSpecMultiSet);
  { will contain all keys that are contained in self or in aSet;
    the multiplicity of a key will become equal to the SUM of the multiplicities of a key in self and aSet }
    procedure ArithmeticAdd(aSet: TSpecMultiSet);
  { will contain only those keys whose multiplicity is greater then the multiplicity
    of that key in aSet; the multiplicity of a key will become equal to the difference of multiplicities
    of a key in self and aSet }
    procedure ArithmeticSubtract(aSet: TSpecMultiSet);
  { will contain only those keys whose multiplicity is not equal to the multiplicity
    of that key in aSet; the multiplicity of a key will become equal to absolute value of difference
    of the multiplicities of a key in self and aSet }
    procedure SymmetricSubtract(aSet: TSpecMultiSet);
  { enumerates underlying set - distinct keys only }
    function  Distinct: IEnumerable;
    function  Entries: IEntryEnumerable;
  { returs number of distinct keys }
    property  EntryCount: SizeInt read GetEntryCount; //dimension, Count - cardinality
  { will return 0 if not contains an element aValue;
    will raise EArgumentException if one try to set negative multiplicity of a aValue }
    property  Counts[const aValue: T]: SizeInt read GetKeyCount write SetKeyCount; default;
  end;

  { TSimpleIterable }

  TSimpleIterable = class
  private
    FItCounter: Integer;
    function  GetInIteration: Boolean; inline;
  protected
    procedure CapacityExceedError(aValue: SizeInt);
    procedure UpdateLockError;
    procedure CheckInIteration; inline;
    procedure BeginIteration; inline;
    procedure EndIteration; inline;
    property  InIteration: Boolean read GetInIteration;
  end;

  { TGAbstractMap: map abstract ancestor class  }
  generic TGAbstractMap<TKey, TValue> = class abstract(TSimpleIterable, specialize IGMap<TKey, TValue>,
    specialize IGReadOnlyMap<TKey, TValue>)
  {must be
    generic TGAbstractMap<TKey, TValue> = class abstract(
      specialize TGAbstractContainer<specialize TGMapEntry<TKey, TValue>>), but in 3.2.0 it doesn't compile}
  public
  type
    TSpecMap         = specialize TGAbstractMap<TKey, TValue>;
    TEntry           = specialize TGMapEntry<TKey, TValue>;
    PValue           = ^TValue;
    IKeyEnumerable   = specialize IGEnumerable<TKey>;
    IValueEnumerable = specialize IGEnumerable<TValue>;
    IEntryEnumerable = specialize IGEnumerable<TEntry>;
    TEntryArray      = specialize TGArray<TEntry>;
    TKeyArray        = specialize TGArray<TKey>;
    TKeyTest         = specialize TGTest<TKey>; ///////
    TOnKeyTest       = specialize TGOnTest<TKey>;
    TNestKeyTest     = specialize TGNestTest<TKey>;
    TKeyOptional     = specialize TGOptional<TKey>;
    TValueOptional   = specialize TGOptional<TValue>;
    TKeyCollection   = specialize TGAbstractCollection<TKey>;
    IKeyCollection   = specialize IGCollection<TKey>;

  protected
  type
    PEntry = ^TEntry;

    TExtractHelper = object
    private
      FCurrIndex: SizeInt;
      FExtracted: TEntryArray;
    public
      procedure OnExtract(p: PEntry);
      procedure Init;
      function  Final: TEntryArray;
    end;

    TCustomKeyEnumerable = class(specialize TGAutoEnumerable<TKey>)
    protected
      FOwner: TSpecMap;
    public
      constructor Create(aMap: TSpecMap);
      destructor Destroy; override;
    end;

    TCustomValueEnumerable = class(specialize TGAutoEnumerable<TValue>)
    protected
      FOwner: TSpecMap;
    public
      constructor Create(aMap: TSpecMap);
      destructor Destroy; override;
    end;

    TCustomEntryEnumerable = class(specialize TGAutoEnumerable<TEntry>)
    protected
      FOwner: TSpecMap;
    public
      constructor Create(aMap: TSpecMap);
      destructor Destroy; override;
    end;

    function  _GetRef: TObject;
    function  GetCount: SizeInt;  virtual; abstract;
    function  GetCapacity: SizeInt; virtual; abstract;
    function  Find(const aKey: TKey): PEntry; virtual; abstract;
    //returns True if aKey found, otherwise inserts (garbage) entry and returns False;
    function  FindOrAdd(const aKey: TKey; out p: PEntry): Boolean; virtual; abstract;
    function  DoExtract(const aKey: TKey; out v: TValue): Boolean; virtual; abstract;
    function  DoRemoveIf(aTest: TKeyTest): SizeInt; virtual; abstract;
    function  DoRemoveIf(aTest: TOnKeyTest): SizeInt; virtual; abstract;
    function  DoRemoveIf(aTest: TNestKeyTest): SizeInt; virtual; abstract;
    function  DoExtractIf(aTest: TKeyTest): TEntryArray; virtual; abstract;
    function  DoExtractIf(aTest: TOnKeyTest): TEntryArray; virtual; abstract;
    function  DoExtractIf(aTest: TNestKeyTest): TEntryArray; virtual; abstract;

    function  DoRemove(const aKey: TKey): Boolean; virtual;
    procedure DoClear; virtual; abstract;
    procedure DoEnsureCapacity(aValue: SizeInt); virtual; abstract;
    procedure DoTrimToFit; virtual; abstract;
    function  GetKeys: IKeyEnumerable; virtual; abstract;
    function  GetValues: IValueEnumerable; virtual; abstract;
    function  GetEntries: IEntryEnumerable; virtual; abstract;

    function  GetValue(const aKey: TKey): TValue; inline;
    function  DoSetValue(const aKey: TKey; const aNewValue: TValue): Boolean; virtual;
    function  DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
    function  DoAddOrSetValue(const aKey: TKey; const aValue: TValue): Boolean; virtual;
    function  DoAddAll(const a: array of TEntry): SizeInt;
    function  DoAddAll(e: IEntryEnumerable): SizeInt;
    function  DoRemoveAll(const a: array of TKey): SizeInt;
    function  DoRemoveAll(e: IKeyEnumerable): SizeInt;
  public
    function  ToArray: TEntryArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear;
    procedure EnsureCapacity(aValue: SizeInt);
  { free unused memory if possible }
    procedure TrimToFit;
  { returns True and aValue mapped to aKey if contains aKey, False otherwise }
    function  TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
  { returns value mapped to aKey or aDefault }
    function  GetValueDef(const aKey: TKey; const aDefault: TValue): TValue; inline;
    function  GetMutValueDef(const aKey: TKey; const aDefault: TValue): PValue;
  { returns True if contains aKey, otherwise adds aKey and returns False }
    function  FindOrAddMutValue(const aKey: TKey; out p: PValue): Boolean;
  { returns True and add TEntry(aKey, aValue) only if not contains aKey }
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;
  { returns True and add e only if not contains e.Key }
    function  Add(const e: TEntry): Boolean; inline;
    procedure AddOrSetValue(const aKey: TKey; const aValue: TValue);
  { returns True if e.Key added, False otherwise }
    function  AddOrSetValue(const e: TEntry): Boolean;
  { will add only entries which keys are absent in map }
    function  AddAll(const a: array of TEntry): SizeInt;
    function  AddAll(e: IEntryEnumerable): SizeInt;
  { returns True and map aNewValue to aKey only if contains aKey, False otherwise }
    function  Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
    function  Contains(const aKey: TKey): Boolean; inline;
    function  NonContains(const aKey: TKey): Boolean;
    function  ContainsAny(const a: array of TKey): Boolean;
    function  ContainsAny(e: IKeyEnumerable): Boolean;
    function  ContainsAll(const a: array of TKey): Boolean;
    function  ContainsAll(e: IKeyEnumerable): Boolean;
    function  Remove(const aKey: TKey): Boolean;
    function  RemoveAll(const a: array of TKey): SizeInt;
    function  RemoveAll(e: IKeyEnumerable): SizeInt;
    function  RemoveIf(aTest: TKeyTest): SizeInt;
    function  RemoveIf(aTest: TOnKeyTest): SizeInt;
    function  RemoveIf(aTest: TNestKeyTest): SizeInt;
    function  Extract(const aKey: TKey; out v: TValue): Boolean;
    function  ExtractIf(aTest: TKeyTest): TEntryArray;
    function  ExtractIf(aTest: TOnKeyTest): TEntryArray;
    function  ExtractIf(aTest: TNestKeyTest): TEntryArray;
    procedure RetainAll({%H-}aCollection: IKeyCollection);
    function  Clone: TSpecMap; virtual; abstract;
    function  Keys: IKeyEnumerable;
    function  Values: IValueEnumerable;
    function  Entries: IEntryEnumerable;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  { reading will raise ELGMapError if an aKey is not present in map }
    property  Items[const aKey: TKey]: TValue read GetValue write AddOrSetValue; default;
  end;

  { TGThreadRWMap: RWLock based concurrent map }
  generic TGThreadRWMap<TKey, TValue> = class
  public
  type
    IMap = specialize IGMap<TKey, TValue>;

  private
  type
    TMap = specialize TGAbstractMap<TKey, TValue>;

  var
    FMap: IMap;
    FRWLock: TMultiReadExclusiveWriteSynchronizer;
    FOwnsMap: Boolean;
    function  GetCount: SizeInt;
    function  GetCapacity: SizeInt;
  protected
    procedure BeginRead; inline;
    procedure BeginWrite; inline;
  public
  type
    IRoMap = specialize IGReadOnlyMap<TKey, TValue>;

    constructor Create(aMap: IMap; aOwnsMap: Boolean = True);
    destructor Destroy; override;
    function  ReadMap: IRoMap;
    procedure EndRead; inline;
    function  WriteMap: IMap;
    procedure EndWrite; inline;
  { returns True and add TEntry(aKey, aValue) only if not contains aKey }
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;
    procedure AddOrSetValue(const aKey: TKey; const aValue: TValue);
    function  TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
    function  GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
  { returns True and map aNewValue to aKey only if contains aKey, False otherwise }
    function  Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
    function  Contains(const aKey: TKey): Boolean;
    function  Extract(const aKey: TKey; out aValue: TValue): Boolean;
    function  Remove(const aKey: TKey): Boolean;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  OwnsMap: Boolean read FOwnsMap;
  end;

  { TGAbstractMultiMap: multimap abstract ancestor class }
  generic TGAbstractMultiMap<TKey, TValue> = class abstract(TSimpleIterable)
  {must be
    generic TGAbstractMultiMap<TKey, TValue> = class abstract(
      specialize TGAbstractContainer<specialize TGMapEntry<TKey, TValue>>), but in 3.2.0 it doesn't compile}
  public
  type
    TEntry           = specialize TGMapEntry<TKey, TValue>;
    IKeyEnumerable   = specialize IGEnumerable<TKey>;
    IValueEnumerable = specialize IGEnumerable<TValue>;
    IEntryEnumerable = specialize IGEnumerable<TEntry>;
    TValueArray      = specialize TGArray<TKey>;

  protected
  type
    TSpecValueEnumerator = specialize TGEnumerator<TValue>;

    TAbstractValueSet = class abstract
    protected
      function GetCount: SizeInt; virtual; abstract;
    public
      function GetEnumerator: TSpecValueEnumerator; virtual; abstract;
      function ToArray: TValueArray;
      function Contains(const aValue: TValue): Boolean; virtual; abstract;
      function Add(const aValue: TValue): Boolean; virtual; abstract;
      function Remove(const aValue: TValue): Boolean; virtual; abstract;
      property Count: SizeInt read GetCount;
    end;

    TMMEntry = record
      Key: TKey;
      Values: TAbstractValueSet;
    end;
    PMMEntry = ^TMMEntry;

    TCustomValueEnumerable = class(specialize TGAutoEnumerable<TValue>)
    protected
      FOwner: TGAbstractMultiMap;
    public
      constructor Create(aMap: TGAbstractMultiMap);
      destructor Destroy; override;
    end;

    TCustomEntryEnumerable = class(specialize TGAutoEnumerable<TEntry>)
    protected
      FOwner: TGAbstractMultiMap;
    public
      constructor Create(aMap: TGAbstractMultiMap);
      destructor Destroy; override;
    end;

    TCustomValueCursor = class(specialize TGEnumCursor<TValue>)
    protected
      FOwner: TGAbstractMultiMap;
    public
      constructor Create(e: TSpecEnumerator; aMap: TGAbstractMultiMap);
      destructor Destroy; override;
    end;

  var
    FCount: SizeInt;
    function  GetKeyCount: SizeInt; virtual; abstract;
    function  GetCapacity: SizeInt; virtual; abstract;
    function  GetUniqueValues: Boolean; virtual; abstract;
    procedure DoClear; virtual; abstract;
    procedure DoEnsureCapacity(aValue: SizeInt); virtual; abstract;
    procedure DoTrimToFit; virtual; abstract;
    function  Find(const aKey: TKey): PMMEntry; virtual; abstract;
    function  FindOrAdd(const aKey: TKey): PMMEntry; virtual; abstract;
    function  DoRemoveKey(const aKey: TKey): SizeInt; virtual; abstract;
    function  GetKeys: IKeyEnumerable; virtual; abstract;
    function  GetValues: IValueEnumerable; virtual; abstract;
    function  GetEntries: IEntryEnumerable; virtual; abstract;

    function  DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
    function  DoAddAll(const a: array of TEntry): SizeInt;
    function  DoAddAll(e: IEntryEnumerable): SizeInt;
    function  DoAddValues(const aKey: TKey; const a: array of TValue): SizeInt;
    function  DoAddValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
    function  DoRemove(const aKey: TKey; const aValue: TValue): Boolean;
    function  DoRemoveAll(const a: array of TEntry): SizeInt;
    function  DoRemoveAll(e: IEntryEnumerable): SizeInt;
    function  DoRemoveValues(const aKey: TKey; const a: array of TValue): SizeInt;
    function  DoRemoveValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
    function  DoRemoveKeys(const a: array of TKey): SizeInt;
    function  DoRemoveKeys(e: IKeyEnumerable): SizeInt;
  public
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure Clear;
    procedure EnsureCapacity(aValue: SizeInt);
    procedure TrimToFit;

    function  Contains(const aKey: TKey): Boolean; inline;
    function  ContainsValue(const aKey: TKey; const aValue: TValue): Boolean;
  { returns True and add TEntry(aKey, aValue) only if value-collection of an aKey adds aValue }
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;
  { returns True and add e only if value-collection of an e.Key adds e.Value }
    function  Add(const e: TEntry): Boolean;
  { returns count of added values }
    function  AddAll(const a: array of TEntry): SizeInt;
    function  AddAll(e: IEntryEnumerable): SizeInt;
    function  AddValues(const aKey: TKey; const a: array of TValue): SizeInt;
    function  AddValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
  { returns True if aKey exists and mapped to aValue; aValue will be removed(and aKey if no more mapped values) }
    function  Remove(const aKey: TKey; const aValue: TValue): Boolean;
    function  Remove(const e: TEntry): Boolean;
    function  RemoveAll(const a: array of TEntry): SizeInt;
    function  RemoveAll(e: IEntryEnumerable): SizeInt;
    function  RemoveValues(const aKey: TKey; const a: array of TValue): SizeInt;
    function  RemoveValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
  { if aKey exists then removes if with mapped values; returns count of removed values }
    function  RemoveKey(const aKey: TKey): SizeInt;
  { returns count of removed values }
    function  RemoveKeys(const a: array of TKey): SizeInt;
  { returns count of removed values }
    function  RemoveKeys(e: IKeyEnumerable): SizeInt;
  { enumerates values mapped to aKey(empty if aKey is missing) }
    function  ValuesView(const aKey: TKey): IValueEnumerable;
    function  Keys: IKeyEnumerable;
    function  Values: IValueEnumerable;
    function  Entries: IEntryEnumerable;
  { returns count of values mapped to aKey (similar as multiset)}
    function  ValueCount(const aKey: TKey): SizeInt;
    property  UniqueValues: Boolean read GetUniqueValues;
    property  Count: SizeInt read FCount;
    property  KeyCount: SizeInt read GetKeyCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[const aKey: TKey]: IValueEnumerable read ValuesView; default;
  end;

  { TGAbstractTable2D: table abstract ancestor class }
  generic TGAbstractTable2D<TRow, TCol, TValue> = class abstract
  {must be
    generic TGAbstractTable2D<TRow, TCol, TValue> = class abstract(
      specialize TGAbstractContainer<specialize TGCell2D<TRow, TCol, TValue>>),
        but in 3.2.0 it doesn't compile}
  public
  type

    TCellData = specialize TGCell2D<TRow, TCol, TValue>;

    TColData = record
      Row:   TRow;
      Value: TValue;
      constructor Create(const aRow: TRow; const aValue: TValue);
    end;

    TRowData = record
      Column: TCol;
      Value:  TValue;
      constructor Create(const aCol: TCol; const aValue: TValue);
    end;

    TSpecTable2D        = TGAbstractTable2D;
    TValueArray         = array of TValue;
    IValueEnumerable    = specialize IGEnumerable<TValue>;
    IColEnumerable      = specialize IGEnumerable<TCol>;
    IRowEnumerable      = specialize IGEnumerable<TRow>;
    IRowDataEnumerable  = specialize IGEnumerable<TRowData>;
    IColDataEnumerable  = specialize IGEnumerable<TColData>;
    ICellDataEnumerable = specialize IGEnumerable<TCellData>;
    TRowDataEnumerator  = class abstract(specialize TGEnumerator<TRowData>);

{$PUSH}{$INTERFACES CORBA}
    IRowMap = interface
      function  GetCount: SizeInt;
      function  GetEnumerator: TRowDataEnumerator;
      function  IsEmpty: Boolean;
      procedure TrimToFit;
      function  Contains(const aCol: TCol): Boolean;
      function  TryGetValue(const aCol: TCol; out aValue: TValue): Boolean;
      function  GetValueOrDefault(const aCol: TCol): TValue;
    { returns True if not contains aCol was added, False otherwise }
      function  Add(const aCol: TCol; const aValue: TValue): Boolean;
      procedure AddOrSetValue(const aCol: TCol; const aValue: TValue);
      function  Remove(const aCol: TCol): Boolean;
      property  Count: SizeInt read GetCount;
      property  Cells[const aCol: TCol]: TValue read GetValueOrDefault write AddOrSetValue; default;
    end;
{$POP}

   IRowMapEnumerable = specialize IGEnumerable<IRowMap>;

  protected
  type
    TCustomRowMap = class(IRowMap)
    protected
      function  GetCount: SizeInt; virtual; abstract;
    public
      function  GetEnumerator: TRowDataEnumerator; virtual; abstract;
      function  IsEmpty: Boolean;
      procedure TrimToFit; virtual; abstract;
      function  Contains(const aCol: TCol): Boolean; virtual; abstract;
      function  TryGetValue(const aCol: TCol; out aValue: TValue): Boolean; virtual; abstract;
      function  GetValueOrDefault(const aCol: TCol): TValue; inline;
    { returns True if not contains aCol was added, False otherwise }
      function  Add(const aCol: TCol; const aValue: TValue): Boolean; virtual; abstract;
      procedure AddOrSetValue(const aCol: TCol; const aValue: TValue); virtual; abstract;
      function  Remove(const aCol: TCol): Boolean; virtual; abstract;
      property  Count: SizeInt read GetCount;
      property  Cells[const aCol: TCol]: TValue read GetValueOrDefault write AddOrSetValue; default;
    end;

    TRowEntry = record
      Key: TRow;
      Columns: TCustomRowMap;
    end;
    PRowEntry = ^TRowEntry;

    TAutoValueEnumerable    = class abstract(specialize TGAutoEnumerable<TValue>);
    TAutoRowDataEnumerable  = class abstract(specialize TGAutoEnumerable<TRowData>);
    TAutoColDataEnumerable  = class abstract(specialize TGAutoEnumerable<TColData>);
    TAutoCellDataEnumerable = class abstract(specialize TGAutoEnumerable<TCellData>);

  var
    FCellCount: SizeInt;
    function  GetRowCount: SizeInt; virtual; abstract;
    function  DoFindRow(const aRow: TRow): PRowEntry; virtual; abstract;
  { returns True if row found, False otherwise }
    function  DoFindOrAddRow(const aRow: TRow; out p: PRowEntry): Boolean; virtual; abstract;
    function  DoRemoveRow(const aRow: TRow): SizeInt; virtual; abstract;
    function  GetColumn(const aCol: TCol): IColDataEnumerable; virtual; abstract;
    function  GetCellData: ICellDataEnumerable; virtual; abstract;
    function  GetColCount(const aRow: TRow): SizeInt;
  { aRow will be added if it is missed }
    function  GetRowMap(const aRow: TRow): IRowMap;
  { will raise exception if cell is missed }
    function  GetCell(const aRow: TRow; const aCol: TCol): TValue;
  public
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure Clear; virtual; abstract;
    procedure TrimToFit; virtual; abstract;
    procedure EnsureRowCapacity(aValue: SizeInt); virtual; abstract;
    function  ContainsRow(const aRow: TRow): Boolean; inline;
    function  FindRow(const aRow: TRow; out aMap: IRowMap): Boolean;
    function  FindOrAddRow(const aRow: TRow): IRowMap;
  { if not contains aRow then add aRow and returns True, False otherwise }
    function  AddRow(const aRow: TRow): Boolean; inline;
    function  AddRows(const a: array of TRow): SizeInt;
  { returns count of the columns in the removed row }
    function  RemoveRow(const aRow: TRow): SizeInt; inline;
  { returns count of the removed cells }
    function  RemoveColumn(const aCol: TCol): SizeInt;
    function  ContainsCell(const aRow: TRow; const aCol: TCol): Boolean;
    function  FindCell(const aRow: TRow; const aCol: TCol; out aValue: TValue): Boolean;
    function  GetCellDef(const aRow: TRow; const aCol: TCol; aDef: TValue): TValue; inline;
    procedure AddOrSetCell(const aRow: TRow; const aCol: TCol; const aValue: TValue);
    function  AddCell(const aRow: TRow; const aCol: TCol; const aValue: TValue): Boolean;
    function  AddCell(const e: TCellData): Boolean; inline;
    function  AddCells(const a: array of TCellData): SizeInt;
    function  RemoveCell(const aRow: TRow; const aCol: TCol): Boolean;

    function  Rows: IRowEnumerable; virtual; abstract;
    function  EnumRowMaps: IRowMapEnumerable; virtual; abstract;
    property  RowCount: SizeInt read GetRowCount;
    property  ColCount[const aRow: TRow]: SizeInt read GetColCount;
    property  CellCount: SizeInt read FCellCount;
    property  RowMaps[const aRow: TRow]: IRowMap read GetRowMap;
    property  Columns[const aCol: TCol]: IColDataEnumerable read GetColumn;
    property  Cells: ICellDataEnumerable read GetCellData;
  { will raise an exception if one try to read the missing cell }
    property  Items[const aRow: TRow; const aCol: TCol]: TValue read GetCell write AddOrSetCell; default;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGEnumerable }

function TGEnumerable._GetRef: TObject;
begin
  Result := Self;
end;

procedure TGEnumerable.Discard;
begin
  GetEnumerator.Free;
end;

function TGEnumerable.Reverse: IEnumerable;
begin
  Result := specialize TGArrayReverse<T>.Create(ToArray);
end;

function TGEnumerable.ToArray: TArray;
var
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    try
      while MoveNext do
        begin
          if I = System.Length(Result) then
            System.SetLength(Result, I + I);
          Result[I] := Current;
          Inc(I);
        end;
    finally
      Free;
    end;
  System.SetLength(Result, I);
end;

function TGEnumerable.Any: Boolean;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
    finally
      Free;
    end;
end;

function TGEnumerable.None: Boolean;
begin
  Result := not Any;
end;

function TGEnumerable.Total: SizeInt;
begin
  Result := 0;
  with GetEnumerator do
    try
      while MoveNext do
        Inc(Result);
    finally
      Free;
    end;
end;

function TGEnumerable.FindFirst(out aValue: T): Boolean;
begin
  with GetEnumerator do
    try
      if MoveNext then
        begin
          aValue := Current;
          exit(True);
        end;
    finally
      Free;
    end;
  Result := False;
end;

function TGEnumerable.First: TOptional;
var
  v: T;
begin
  if FindFirst(v) then
    Result.Assign(v);
end;

function TGEnumerable.FindLast(out aValue: T): Boolean;
begin
  with GetEnumerator do
    try
      if MoveNext then
        begin
          while MoveNext do;
          aValue := Current; //todo: ???
          exit(True);
        end;
    finally
      Free;
    end;
  Result := False;
end;

function TGEnumerable.Last: TOptional;
var
  v: T;
begin
  if FindLast(v) then
    Result.Assign(v);
end;

function TGEnumerable.FindMin(out aValue: T; c: TLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(v, aValue) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.FindMin(out aValue: T; c: TOnLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(v, aValue) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.FindMin(out aValue: T; c: TNestLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(v, aValue) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.Min(c: TLess): TOptional;
var
  v: T;
begin
  if FindMin(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.Min(c: TOnLess): TOptional;
var
  v: T;
begin
  if FindMin(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.Min(c: TNestLess): TOptional;
var
  v: T;
begin
  if FindMin(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.FindMax(out aValue: T; c: TLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(aValue, v) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.FindMax(out aValue: T; c: TOnLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(aValue, v) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.FindMax(out aValue: T; c: TNestLess): Boolean;
var
  v: T;
begin
  with GetEnumerator do
    try
      Result := MoveNext;
      if Result then
        begin
          aValue := Current;
          while MoveNext do
            begin
              v := Current;
              if c(aValue, v) then
                aValue := v;
            end;
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.Max(c: TLess): TOptional;
var
  v: T;
begin
  if FindMax(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.Max(c: TOnLess): TOptional;
var
  v: T;
begin
  if FindMax(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.Max(c: TNestLess): TOptional;
var
  v: T;
begin
  if FindMax(v, c) then
    Result.Assign(v);
end;

function TGEnumerable.Skip(aCount: SizeInt): IEnumerable;
begin
  Result := specialize TGSkipEnumerable<T>.Create(GetEnumerator, aCount);
end;

function TGEnumerable.SkipWhile(aTest: TTest): IEnumerable;
begin
  Result := specialize TGRegularSkipWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.SkipWhile(aTest: TOnTest): IEnumerable;
begin
  Result := specialize TGDelegatedSkipWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.SkipWhile(aTest: TNestTest): IEnumerable;
begin
  Result := specialize TGNestedSkipWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.Limit(aCount: SizeInt): IEnumerable;
begin
  Result := specialize TGLimitEnumerable<T>.Create(GetEnumerator, aCount);
end;

function TGEnumerable.TakeWhile(aTest: TTest): IEnumerable;
begin
  Result := specialize TGRegularTakeWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.TakeWhile(aTest: TOnTest): IEnumerable;
begin
  Result := specialize TGDelegatedTakeWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.TakeWhile(aTest: TNestTest): IEnumerable;
begin
  Result := specialize TGNestedTakeWhileEnumerable<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.Sorted(c: TLess; aStable: Boolean): IEnumerable;
var
  a: TArray;
begin
  a := ToArray;
  if aStable then
    specialize TGRegularArrayHelper<T>.MergeSort(a, c)
  else
    specialize TGRegularArrayHelper<T>.Sort(a, c);
  Result := specialize TGArrayCursor<T>.Create(a);
end;

function TGEnumerable.Sorted(c: TOnLess; aStable: Boolean): IEnumerable;
var
  a: TArray;
begin
  a := ToArray;
  if aStable then
    specialize TGDelegatedArrayHelper<T>.MergeSort(a, c)
  else
    specialize TGDelegatedArrayHelper<T>.Sort(a, c);
  Result := specialize TGArrayCursor<T>.Create(a);
end;

function TGEnumerable.Sorted(c: TNestLess; aStable: Boolean): IEnumerable;
var
  a: TArray;
begin
  a := ToArray;
  if aStable then
    specialize TGNestedArrayHelper<T>.MergeSort(a, c)
  else
    specialize TGNestedArrayHelper<T>.Sort(a, c);
  Result := specialize TGArrayCursor<T>.Create(a);
end;

function TGEnumerable.Sorted(aSort: specialize TGSortProc<T>; o: TSortOrder): IEnumerable;
var
  a: TArray;
begin
  if aSort = nil then
    raise EArgumentNilException.Create(SESortProcNotAssigned);
  a := ToArray;
  aSort(a, o);
  Result := specialize TGArrayCursor<T>.Create(a);
end;

function TGEnumerable.Select(aTest: TTest): IEnumerable;
begin
  Result := specialize TGEnumRegularFilter<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.Select(aTest: TOnTest): IEnumerable;
begin
  Result := specialize TGEnumDelegatedFilter<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.Select(aTest: TNestTest): IEnumerable;
begin
  Result := specialize TGEnumNestedFilter<T>.Create(GetEnumerator, aTest);
end;

function TGEnumerable.Any(aTest: TTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if aTest(Current) then
          exit(True);
    finally
      Free;
    end;
  Result := False;
end;

function TGEnumerable.Any(aTest: TOnTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if aTest(Current) then
          exit(True);
    finally
      Free;
    end;
  Result := False;
end;

function TGEnumerable.Any(aTest: TNestTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if aTest(Current) then
          exit(True);
    finally
      Free;
    end;
  Result := False;
end;

function TGEnumerable.None(aTest: TTest): Boolean;
begin
  Result := not Any(aTest);
end;

function TGEnumerable.None(aTest: TOnTest): Boolean;
begin
  Result := not Any(aTest);
end;

function TGEnumerable.None(aTest: TNestTest): Boolean;
begin
  Result := not Any(aTest);
end;

function TGEnumerable.All(aTest: TTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if not aTest(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGEnumerable.All(aTest: TOnTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if not aTest(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGEnumerable.All(aTest: TNestTest): Boolean;
begin
  with GetEnumerator do
    try
      while MoveNext do
        if not aTest(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGEnumerable.Total(aTest: TTest): SizeInt;
begin
  Result := 0;
  with GetEnumerator do
    try
      while MoveNext do
        Result += Ord(aTest(Current));
    finally
      Free;
    end;
end;

function TGEnumerable.Total(aTest: TOnTest): SizeInt;
begin
  Result := 0;
  with GetEnumerator do
    try
      while MoveNext do
        Result += Ord(aTest(Current));
    finally
      Free;
    end;
end;

function TGEnumerable.Total(aTest: TNestTest): SizeInt;
begin
  Result := 0;
  with GetEnumerator do
    try
      while MoveNext do
        Result += Ord(aTest(Current));
    finally
      Free;
    end;
end;

function TGEnumerable.Distinct(c: TLess): IEnumerable;
begin
  Result := specialize TGArrayCursor<T>.Create(
    specialize TGRegularArrayHelper<T>.SelectDistinct(ToArray, c));
end;

function TGEnumerable.Distinct(c: TOnLess): IEnumerable;
begin
  Result := specialize TGArrayCursor<T>.Create(
    specialize TGDelegatedArrayHelper<T>.SelectDistinct(ToArray, c));
end;

function TGEnumerable.Distinct(c: TNestLess): IEnumerable;
begin
  Result := specialize TGArrayCursor<T>.Create(
    specialize TGNestedArrayHelper<T>.SelectDistinct(ToArray, c));
end;

function TGEnumerable.Map(aMap: TMapFunc): IEnumerable;
begin
  Result := specialize TGEnumRegularMap<T>.Create(GetEnumerator, aMap);
end;

function TGEnumerable.Map(aMap: TOnMap): IEnumerable;
begin
  Result := specialize TGEnumDelegatedMap<T>.Create(GetEnumerator, aMap);
end;

function TGEnumerable.Map(aMap: TNestMap): IEnumerable;
begin
  Result := specialize TGEnumNestedMap<T>.Create(GetEnumerator, aMap);
end;

procedure TGEnumerable.ForEach(aCallback: TUnaryProc);
begin
  with GetEnumerator do
    try
      while MoveNext do
        aCallback(Current);
    finally
      Free;
    end;
end;

procedure TGEnumerable.ForEach(aCallback: TUnaryMethod);
begin
  with GetEnumerator do
    try
      while MoveNext do
        aCallback(Current);
    finally
      Free;
    end;
end;

procedure TGEnumerable.ForEach(aCallback: TNestUnaryProc);
begin
  with GetEnumerator do
    try
      while MoveNext do
        aCallback(Current);
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TFold; const aInitVal: T): T;
begin
  Result := aInitVal;
  with GetEnumerator do
    try
      while MoveNext do
        Result := aFold(Current, Result);
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TFold): TOptional;
var
  v: T;
begin
  with GetEnumerator do
    try
      if MoveNext then
        begin
          v := aFold(Current, Default(T));
          while MoveNext do
            v := aFold(Current, v);
          Result.Assign(v);
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TOnFold; const aInitVal: T): T;
begin
  Result := aInitVal;
  with GetEnumerator do
    try
      while MoveNext do
        Result := aFold(Current, Result);
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TOnFold): TOptional;
var
  v: T;
begin
  with GetEnumerator do
    try
      if MoveNext then
        begin
          v := aFold(Current, Default(T));
          while MoveNext do
            v := aFold(Current, v);
          Result.Assign(v);
        end;
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TNestFold; const aInitVal: T): T;
begin
  Result := aInitVal;
  with GetEnumerator do
    try
      while MoveNext do
        Result := aFold(Current, Result);
    finally
      Free;
    end;
end;

function TGEnumerable.Fold(aFold: TNestFold): TOptional;
var
  v: T;
begin
  with GetEnumerator do
    try
      if MoveNext then
        begin
          v := aFold(Current, Default(T));
          while MoveNext do
            v := aFold(Current, v);
          Result.Assign(v);
        end;
    finally
      Free;
    end;
end;

{$I Enums.inc}

{ TGAbstractContainer.TGContainerEnumerator }

constructor TGAbstractContainer.TContainerEnumerator.Create(c: TSpecContainer);
begin
  FOwner := c;
end;

destructor TGAbstractContainer.TContainerEnumerator.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractContainer.TContainerEnumerable }

constructor TGAbstractContainer.TContainerEnumerable.Create(c: TSpecContainer);
begin
  inherited Create;
  FOwner := c;
end;

destructor TGAbstractContainer.TContainerEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractContainer }

function TGAbstractContainer.GetInIteration: Boolean;
begin
  Result := Boolean(LongBool(FItCounter));
end;

procedure TGAbstractContainer.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SEClassCapacityExceedFmt, [ClassName, aValue]);
end;

procedure TGAbstractContainer.AccessEmptyError;
begin
  raise ELGAccessEmpty.CreateFmt(SEClassAccessEmptyFmt, [ClassName]);
end;

procedure TGAbstractContainer.IndexOutOfBoundError(aIndex: SizeInt);
begin
  raise ELGListError.CreateFmt(SEClassIdxOutOfBoundsFmt, [ClassName, aIndex]);
end;

procedure TGAbstractContainer.UpdateLockError;
begin
  raise ELGUpdateLock.CreateFmt(SECantUpdDuringIterFmt, [ClassName]);
end;

procedure TGAbstractContainer.CheckInIteration;
begin
  if InIteration then
    UpdateLockError;
end;

procedure TGAbstractContainer.BeginIteration;
begin
  Inc(FItCounter);
end;

procedure TGAbstractContainer.EndIteration;
begin
  Dec(FItCounter);
end;

procedure TGAbstractContainer.CopyItems(aBuffer: PItem);
begin
  with GetEnumerator do
    try
      while MoveNext do
        begin
          aBuffer^ := Current;
          Inc(aBuffer);
        end;
    finally
      Free;
    end;
end;

function TGAbstractContainer.GetEnumerator: TSpecEnumerator;
begin
  BeginIteration;
  Result := DoGetEnumerator;
end;

function TGAbstractContainer.ToArray: TArray;
var
  c: SizeInt;
begin
  c := Count;
  System.SetLength(Result, c);
  if c > 0 then
    CopyItems(@Result[0]);
end;

function TGAbstractContainer.IsEmpty: Boolean;
begin
  Result := GetCount = 0;
end;

function TGAbstractContainer.NonEmpty: Boolean;
begin
  Result := GetCount <> 0;
end;

procedure TGAbstractContainer.Clear;
begin
  CheckInIteration;
  DoClear;
end;

procedure TGAbstractContainer.TrimToFit;
begin
  CheckInIteration;
  DoTrimToFit;
end;

procedure TGAbstractContainer.EnsureCapacity(aValue: SizeInt);
begin
  CheckInIteration;
  DoEnsureCapacity(aValue);
end;

{$I DynBuffer.inc}

{ TGAbstractCollection }

function TGAbstractCollection.DoRemove(const aValue: T): Boolean;
begin
  Result := DoExtract(aValue);
end;

function TGAbstractCollection.DoAddAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    DoAdd(a[I]);
  Result := Count - Result;
end;

function TGAbstractCollection.DoRemoveAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if NonEmpty then
    for I := 0 to System.High(a) do
      if DoRemove(a[I]) then
        if IsEmpty then
          break;
  Result -= Count;
end;

function TGAbstractCollection.DoRemoveAll(e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  o := e._GetRef;
  if o <> Self then
    begin
      Result := Count;
      if Count > 0 then
        begin
          with e.GetEnumerator do
            try
              while MoveNext do
                if DoRemove(Current) and IsEmpty then
                  break;
            finally
              Free;
            end;
          Result -= Count;
        end
      else
        e.Discard;
    end
  else
    begin
      Result := Count;
      DoClear;
    end;
end;

function TGAbstractCollection.Add(const aValue: T): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(aValue);
end;

function TGAbstractCollection.AddAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := DoAddAll(a);
end;

function TGAbstractCollection.AddAll(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoAddAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractCollection.NonContains(const aValue: T): Boolean;
begin
  Result := not Contains(aValue);
end;

function TGAbstractCollection.ContainsAny(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if NonEmpty then
    for I := 0 to System.High(a) do
      if Contains(a[I]) then
        exit(True);
  Result := False;
end;

function TGAbstractCollection.ContainsAny(e: IEnumerable): Boolean;
begin
  if e._GetRef <> Self then
    begin
      if NonEmpty then
        with e.GetEnumerator do
          try
            while MoveNext do
              if Contains(Current) then
                exit(True);
          finally
            Free;
          end
      else
        e.Discard;
      Result := False;
    end
  else
    Result := NonEmpty;
end;

function TGAbstractCollection.ContainsAll(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if IsEmpty then exit(System.Length(a) = 0);
  for I := 0 to System.High(a) do
    if not Contains(a[I]) then
      exit(False);
  Result := True;
end;

function TGAbstractCollection.ContainsAll(e: IEnumerable): Boolean;
begin
  if IsEmpty then exit(e.None);
  if e._GetRef <> Self then
    with e.GetEnumerator do
      try
        while MoveNext do
          if not Contains(Current) then
            exit(False);
      finally
        Free;
      end;
  Result := True;
end;

function TGAbstractCollection.Remove(const aValue: T): Boolean;
begin
  CheckInIteration;
  Result := DoRemove(aValue);
end;

function TGAbstractCollection.RemoveAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveAll(a);
end;

function TGAbstractCollection.RemoveAll(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractCollection.RemoveIf(aTest: TTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractCollection.RemoveIf(aTest: TOnTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractCollection.RemoveIf(aTest: TNestTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractCollection.Extract(const aValue: T): Boolean;
begin
  CheckInIteration;
  Result := DoExtract(aValue);
end;

function TGAbstractCollection.ExtractIf(aTest: TTest): TArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

function TGAbstractCollection.ExtractIf(aTest: TOnTest): TArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

function TGAbstractCollection.ExtractIf(aTest: TNestTest): TArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

procedure TGAbstractCollection.RetainAll(aCollection: ICollection);
begin
  if aCollection._GetRef <> Self then
    begin
      CheckInIteration;
      DoRemoveIf(@aCollection.NonContains);
    end;
end;

{ TGThreadCollection }

procedure TGThreadCollection.Lock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadCollection.Create(aCollection: ICollection; aOwnsCollection: Boolean);
begin
  System.InitCriticalSection(FLock);
  FCollection := aCollection;
  FOwnsColl := aOwnsCollection;
end;

destructor TGThreadCollection.Destroy;
begin
  Lock;
  try
    if OwnsCollection then
      FCollection._GetRef.Free;
    FCollection := nil;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGThreadCollection.LockCollection: ICollection;
begin
  Result := FCollection;
  Lock;
end;

procedure TGThreadCollection.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGThreadCollection.Clear;
begin
  Lock;
  try
    FCollection.Clear;
  finally
    UnLock;
  end;
end;

function TGThreadCollection.Contains(const aValue: T): Boolean;
begin
  Lock;
  try
    Result := FCollection.Contains(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadCollection.Add(const aValue: T): Boolean;
begin
  Lock;
  try
    Result := FCollection.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadCollection.Remove(const aValue: T): Boolean;
begin
  Lock;
  try
    Result := FCollection.Remove(aValue);
  finally
    UnLock;
  end;
end;

{ TGThreadRWCollection }

function TGThreadRWCollection.GetCapacity: SizeInt;
begin
  FRWLock.BeginRead;
  try
    Result := FCollection.Capacity;
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWCollection.GetCount: SizeInt;
begin
  FRWLock.BeginRead;
  try
    Result := FCollection.Count;
  finally
    FRWLock.EndRead;
  end;
end;

procedure TGThreadRWCollection.BeginRead;
begin
  FRWLock.BeginRead;
end;

procedure TGThreadRWCollection.BeginWrite;
begin
  FRWLock.BeginWrite;
end;

constructor TGThreadRWCollection.Create(aCollection: ICollection; aOwnsCollection: Boolean);
begin
  FRWLock := TMultiReadExclusiveWriteSynchronizer.Create;
  FCollection := aCollection;
  FOwnsColl := aOwnsCollection;
end;

destructor TGThreadRWCollection.Destroy;
begin
  FRWLock.BeginWrite;
  try
    if OwnsCollection then
      FCollection._GetRef.Free;
    FCollection := nil;
    inherited;
  finally
    FRWLock.EndWrite;
    FRWLock.Free;
  end;
end;

function TGThreadRWCollection.ReadCollection: IRoCollection;
begin
  FRWLock.BeginRead;
  Result := TCollection(FCollection._GetRef);
end;

procedure TGThreadRWCollection.EndRead;
begin
  FRWLock.EndRead;
end;

function TGThreadRWCollection.WriteCollection: ICollection;
begin
  FRWLock.BeginWrite;
  Result := FCollection;
end;

procedure TGThreadRWCollection.EndWrite;
begin
  FRWLock.EndWrite;
end;

function TGThreadRWCollection.Contains(const aValue: T): Boolean;
begin
  FRWLock.BeginRead;
  try
    Result := FCollection.Contains(aValue);
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWCollection.Add(const aValue: T): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FCollection.Add(aValue);
  finally
    FRWLock.EndWrite;
  end;
end;

function TGThreadRWCollection.Remove(const aValue: T): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FCollection.Remove(aValue);
  finally
    FRWLock.EndWrite;
  end;
end;

{ TGAbstractSet.TExtractHelper }

procedure TGAbstractSet.TExtractHelper.OnExtract(p: PEntry);
var
  c: SizeInt;
begin
  c := System.Length(FExtracted);
  if FCurrIndex = c then
    System.SetLength(FExtracted, c shl 1);
  FExtracted[FCurrIndex] := p^.Key;
  Inc(FCurrIndex);
end;

procedure TGAbstractSet.TExtractHelper.Init;
begin
  FCurrIndex := 0;
  System.SetLength(FExtracted, ARRAY_INITIAL_SIZE);
end;

function TGAbstractSet.TExtractHelper.Final: TArray;
begin
  System.SetLength(FExtracted, FCurrIndex);
  Result := FExtracted;
end;

{ TGAbstractSet }

function TGAbstractSet.DoAddAll(e: IEnumerable): SizeInt;
begin
  if e._GetRef <> Self then
    begin
      Result := Count;
      with e.GetEnumerator do
        try
          while MoveNext do
            DoAdd(Current);
        finally
          Free;
        end;
      Result := Count - Result;
    end
  else
    Result := 0;
end;

procedure TGAbstractSet.DoSymmetricSubtract(aSet: TSpecSet);
var
  v: T;
begin
  if aSet <> Self then
    begin
      for v in aSet do
        if not DoRemove(v) then
          DoAdd(v);
    end
  else
    Clear;
end;

function TGAbstractSet.IsSuperset(aSet: TSpecSet): Boolean;
begin
  if aSet <> Self then
    begin
      if Count >= aSet.Count then
        Result := ContainsAll(aSet)
      else
        Result := False;
    end
  else
    Result := True;
end;

function TGAbstractSet.IsSubset(aSet: TSpecSet): Boolean;
begin
  Result := aSet.IsSuperset(Self);
end;

function TGAbstractSet.IsEqual(aSet: TSpecSet): Boolean;
begin
  if aSet <> Self then
    Result := (Count = aSet.Count) and ContainsAll(aSet)
  else
    Result := True;
end;

function TGAbstractSet.Intersecting(aSet: TSpecSet): Boolean;
begin
  Result := ContainsAny(aSet);
end;

procedure TGAbstractSet.Intersect(aSet: TSpecSet);
begin
  RetainAll(aSet);
end;

procedure TGAbstractSet.Join(aSet: TSpecSet);
begin
  AddAll(aSet);
end;

procedure TGAbstractSet.Subtract(aSet: TSpecSet);
begin
  RemoveAll(aSet);
end;

procedure TGAbstractSet.SymmetricSubtract(aSet: TSpecSet);
begin
  CheckInIteration;
  DoSymmetricSubtract(aSet);
end;

{ TGAbstractMultiSet.TExtractor }

procedure TGAbstractMultiSet.TExtractHelper.OnExtract(p: PEntry);
var
  I, LastKey: SizeInt;
  Key: T;
begin
  LastKey := Pred(FCurrIndex + p^.Count);
  Key := p^.Key;
  if LastKey >= System.Length(FExtracted) then
      System.SetLength(FExtracted, RoundUpTwoPower(Succ(LastKey)));
  for I := FCurrIndex to LastKey do
    FExtracted[I] := Key;
  FCurrIndex := Succ(LastKey);
end;

procedure TGAbstractMultiSet.TExtractHelper.Init;
begin
  FCurrIndex := 0;
  System.SetLength(FExtracted, ARRAY_INITIAL_SIZE);
end;

function TGAbstractMultiSet.TExtractHelper.Final: TArray;
begin
  System.SetLength(FExtracted, FCurrIndex);
  Result := FExtracted;
end;

{ TGAbstractMultiSet.TIntersectHelper }

function TGAbstractMultiSet.TIntersectHelper.OnIntersect(p: PEntry): Boolean;
var
  c, SetCount: SizeInt;
begin
  SetCount := FOtherSet[p^.Key];
  c := p^.Count;
  if SetCount > 0 then
    begin
      Result := False;
      if SetCount < c then
        begin
          FSet.FCount -= c - SetCount;
          p^.Count := SetCount;
        end;
    end
  else
    Result := True;
end;

{ TGAbstractMultiSet }

function TGAbstractMultiSet.GetCount: SizeInt;
begin
  Result := FCount;
end;

procedure TGAbstractMultiSet.DoJoinEntry(const e: TEntry);
var
  p: PEntry;
begin
  if not FindOrAdd(e.Key, p) then
    begin
      p^.Count := e.Count;
      FCount += e.Count;
    end
  else
    if e.Count > p^.Count then
      begin
        FCount += e.Count - p^.Count;
        p^.Count := e.Count;
      end;
end;

procedure TGAbstractMultiSet.DoAddEntry(const e: TEntry);
var
  p: PEntry;
begin
  FCount += e.Count;
  if not FindOrAdd(e.Key, p) then
    p^.Count := e.Count
  else
    p^.Count += e.Count;
end;

function TGAbstractMultiSet.GetKeyCount(const aKey: T): SizeInt;
var
  p: PEntry;
begin
  p := FindEntry(aKey);
  if p <> nil then
    Result := p^.Count
  else
    Result := 0;
end;

procedure TGAbstractMultiSet.SetKeyCount(const aKey: T; aValue: SizeInt);
var
  p: PEntry;
  e: TEntry;
begin
  if aValue < 0 then
    raise EArgumentException.CreateFmt(SECantAcceptNegCountFmt, [ClassName]);
  CheckInIteration;
  if aValue > 0 then
    begin
      if FindOrAdd(aKey, p) then
        begin
          FCount += aValue - p^.Count;
          p^.Count := aValue;
        end
      else
        begin
          FCount += aValue;
          p^.Count := aValue;
        end;
    end
  else
    begin  // aValue = 0;
      e.Key := aKey;
      e.Count := High(SizeInt);
      DoSubEntry(e);
    end;
end;

procedure TGAbstractMultiSet.DoArithAdd(aSet: TSpecMultiSet);
var
  e: TEntry;
begin
  if aSet <> Self then
    for e in aSet.Entries do
      DoAddEntry(e)
  else
    DoDoubleEntryCounters;
end;

procedure TGAbstractMultiSet.DoArithSubtract(aSet: TSpecMultiSet);
var
  e: TEntry;
begin
  if aSet <> Self then
    for e in aSet.Entries do
      DoSubEntry(e)
  else
    Clear;
end;

procedure TGAbstractMultiSet.DoSymmSubtract(aSet: TSpecMultiSet);
var
  e: TEntry;
begin
  if aSet <> Self then
    for e in aSet.Entries do
      DoSymmSubEntry(e)
  else
    Clear;
end;

function TGAbstractMultiSet.DoAdd(const aKey: T): Boolean;
var
  p: PEntry;
begin
  Inc(FCount);
  if FindOrAdd(aKey, p) then
    Inc(p^.Count);
  Result := True;
end;
function TGAbstractMultiSet.DoAddAll(e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecMultiSet then
    begin
      Result := ElemCount;
      DoArithAdd(TSpecMultiSet(o));
      Result := ElemCount - Result;
    end
  else
    begin
      Result := Count;
      with e.GetEnumerator do
        try
          while MoveNext do
            DoAdd(Current);
        finally
          Free;
        end;
      Result := Count - Result;
    end;
end;

function TGAbstractMultiSet.DoRemoveAll(e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecMultiSet then
    begin
      Result := ElemCount;
      DoArithSubtract(TSpecMultiSet(o));
      Result -= ElemCount;
    end
  else
    begin
      Result := ElemCount;
      if Result > 0 then
        begin
          with e.GetEnumerator do
            try
              while MoveNext do
                if DoRemove(Current) and (ElemCount = 0) then
                  break;
            finally
              Free;
            end;
          Result -= ElemCount;
        end
      else
        e.Discard;
    end;
end;

function TGAbstractMultiSet.Contains(const aValue: T): Boolean;
begin
  Result := FindEntry(aValue) <> nil;
end;

function TGAbstractMultiSet.IsSuperSet(aSet: TSpecMultiSet): Boolean;
var
  e: TEntry;
begin
  if aSet <> Self then
    begin
      if (Count >= aSet.Count) and (EntryCount >= aSet.EntryCount) then
        begin
          for e in aSet.Entries do
            if GetKeyCount(e.Key) < e.Count then
              exit(False);
          Result := True;
        end
      else
        Result := False;
    end
  else
    Result := True;
end;

function TGAbstractMultiSet.IsSubSet(aSet: TSpecMultiSet): Boolean;
var
  e: TEntry;
begin
  if aSet <> Self then
    begin
      if (aSet.Count >= Count) and (aSet.EntryCount >= EntryCount) then
        begin
          for e in Entries do
            if aSet[e.Key] < e.Count then
              exit(False);
          Result := True;
        end
      else
        Result := False;
    end
  else
    Result := True;
end;

function TGAbstractMultiSet.IsEqual(aSet: TSpecMultiSet): Boolean;
var
  e: TEntry;
begin
  if aSet <> Self then
    begin
      if (aSet.Count = Count) and (aSet.EntryCount = EntryCount) then
        begin
          for e in Entries do
            if aSet[e.Key] <> e.Count then
              exit(False);
          Result := True;
        end
      else
        Result := False;
    end
  else
    Result := True;
end;

function TGAbstractMultiSet.Intersecting(aSet: TSpecMultiSet): Boolean;
begin
  Result := ContainsAny(aSet.Distinct);
end;

procedure TGAbstractMultiSet.Intersect(aSet: TSpecMultiSet);
begin
  if aSet <> Self then
    begin
      CheckInIteration;
      DoIntersect(aSet);
    end;
end;

procedure TGAbstractMultiSet.Join(aSet: TSpecMultiSet);
var
  e: TEntry;
begin
  if aSet <> Self then
    begin
      CheckInIteration;
      for e in aSet.Entries do
        DoJoinEntry(e);
    end;
end;

procedure TGAbstractMultiSet.ArithmeticAdd(aSet: TSpecMultiSet);
begin
  CheckInIteration;
  DoArithAdd(aSet);
end;

procedure TGAbstractMultiSet.ArithmeticSubtract(aSet: TSpecMultiSet);
begin
  CheckInIteration;
  DoArithSubtract(aSet);
end;

procedure TGAbstractMultiSet.SymmetricSubtract(aSet: TSpecMultiSet);
begin
  CheckInIteration;
  DoSymmSubtract(aSet);
end;

function TGAbstractMultiSet.Distinct: IEnumerable;
begin
  BeginIteration;
  Result := GetDistinct;
end;

function TGAbstractMultiSet.Entries: IEntryEnumerable;
begin
  BeginIteration;
  Result := GetEntries;
end;

{ TSimpleIterable }

function TSimpleIterable.GetInIteration: Boolean;
begin
  Result := Boolean(LongBool(FItCounter));
end;

procedure TSimpleIterable.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SEClassCapacityExceedFmt, [ClassName, aValue]);
end;

procedure TSimpleIterable.UpdateLockError;
begin
  raise ELGUpdateLock.CreateFmt(SECantUpdDuringIterFmt, [ClassName]);
end;

procedure TSimpleIterable.CheckInIteration;
begin
  if InIteration then
    UpdateLockError;
end;

procedure TSimpleIterable.BeginIteration;
begin
  Inc(FItCounter);
end;

procedure TSimpleIterable.EndIteration;
begin
  Dec(FItCounter);
end;

{ TGAbstractMap.TExtractHelper }

procedure TGAbstractMap.TExtractHelper.OnExtract(p: PEntry);
var
  c: SizeInt;
begin
  c := System.Length(FExtracted);
  if FCurrIndex = c then
    System.SetLength(FExtracted, c shl 1);
  FExtracted[FCurrIndex] := p^;
  Inc(FCurrIndex);
end;

procedure TGAbstractMap.TExtractHelper.Init;
begin
  FCurrIndex := 0;
  System.SetLength(FExtracted, ARRAY_INITIAL_SIZE);
end;

function TGAbstractMap.TExtractHelper.Final: TEntryArray;
begin
  System.SetLength(FExtracted, FCurrIndex);
  Result := FExtracted;
end;

{ TGAbstractMap.TCustomKeyEnumerable }

constructor TGAbstractMap.TCustomKeyEnumerable.Create(aMap: TSpecMap);
begin
  inherited Create;
  FOwner := aMap;
end;

destructor TGAbstractMap.TCustomKeyEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMap.TCustomValueEnumerable }

constructor TGAbstractMap.TCustomValueEnumerable.Create(aMap: TSpecMap);
begin
  inherited Create;
  FOwner := aMap;
end;

destructor TGAbstractMap.TCustomValueEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMap.TCustomEntryEnumerable }

constructor TGAbstractMap.TCustomEntryEnumerable.Create(aMap: TSpecMap);
begin
  inherited Create;
  FOwner := aMap;
end;

destructor TGAbstractMap.TCustomEntryEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMap }

function TGAbstractMap._GetRef: TObject;
begin
  Result := Self;
end;

function TGAbstractMap.DoRemove(const aKey: TKey): Boolean;
var
  v: TValue;
begin
  Result := DoExtract(aKey, v);
end;

function TGAbstractMap.GetValue(const aKey: TKey): TValue;
begin
  if not TryGetValue(aKey, Result) then
    raise ELGMapError.Create(SEKeyNotFound);
end;

function TGAbstractMap.DoSetValue(const aKey: TKey; const aNewValue: TValue): Boolean;
var
  p: PEntry;
begin
  p := Find(aKey);
  if p <> nil then
    begin
      p^.Value := aNewValue;
      exit(True);
    end;
  Result := False;
end;

function TGAbstractMap.DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
var
  p: PEntry;
begin
  if not FindOrAdd(aKey, p) then
    begin
      p^.Value := aValue;
      exit(True);
    end;
  Result := False;
end;

function TGAbstractMap.DoAddOrSetValue(const aKey: TKey; const aValue: TValue): Boolean;
var
  p: PEntry;
begin
  Result := not FindOrAdd(aKey, p);
  p^.Value := aValue;
end;

function TGAbstractMap.DoAddAll(const a: array of TEntry): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    with a[I] do
      DoAdd(Key, Value);
  Result := Count - Result;
end;

function TGAbstractMap.DoAddAll(e: IEntryEnumerable): SizeInt;
begin
  Result := Count;
  if e._GetRef <> Self then
    with e.GetEnumerator do
      try
        while MoveNext do
          with Current do
            DoAdd(Key, Value);
      finally
        Free;
      end;
  Result := Count - Result;
end;

function TGAbstractMap.DoRemoveAll(const a: array of TKey): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if DoRemove(a[I]) then
          if Count = 0 then
            break;
      Result -= Count;
    end;
end;

function TGAbstractMap.DoRemoveAll(e: IKeyEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if DoRemove(Current) and (Count = 0) then
              break;
        finally
          Free;
        end;
      Result -= Count;
    end
  else
    e.Discard;
end;

function TGAbstractMap.ToArray: TEntryArray;
var
  I: Integer = 0;
  e: TEntry;
begin
  System.SetLength(Result, Count);
  for e in Entries do
    begin
      Result[I] := e;
      Inc(I);
    end;
end;

function TGAbstractMap.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGAbstractMap.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGAbstractMap.Clear;
begin
  CheckInIteration;
  DoClear;
end;

procedure TGAbstractMap.EnsureCapacity(aValue: SizeInt);
begin
  CheckInIteration;
  DoEnsureCapacity(aValue);
end;

procedure TGAbstractMap.TrimToFit;
begin
  CheckInIteration;
  DoTrimToFit;
end;

function TGAbstractMap.TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
var
  p: PEntry;
begin
  p := Find(aKey);
  if p <> nil then
    begin
      aValue := p^.Value;
      exit(True);
    end;
  Result := False;
end;

function TGAbstractMap.GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
begin
  if not TryGetValue(aKey, Result) then
    Result := aDefault;
end;

function TGAbstractMap.GetMutValueDef(const aKey: TKey; const aDefault: TValue): PValue;
var
  pe: PEntry;
begin
  CheckInIteration;
  if not FindOrAdd(aKey, pe) then
    pe^.Value := aDefault;
  Result := @pe^.Value;
end;

function TGAbstractMap.FindOrAddMutValue(const aKey: TKey; out p: PValue): Boolean;
var
  pe: PEntry;
begin
  CheckInIteration;
  Result := FindOrAdd(aKey, pe);
  p := @pe^.Value;
end;

function TGAbstractMap.Add(const aKey: TKey; const aValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(aKey, aValue);
end;

function TGAbstractMap.Add(const e: TEntry): Boolean;
begin
  Result := Add(e.Key, e.Value);
end;

procedure TGAbstractMap.AddOrSetValue(const aKey: TKey; const aValue: TValue);
begin
  CheckInIteration;
  DoAddOrSetValue(aKey, aValue);
end;

function TGAbstractMap.AddOrSetValue(const e: TEntry): Boolean;
begin
  CheckInIteration;
  Result := DoAddOrSetValue(e.Key, e.Value);
end;

function TGAbstractMap.AddAll(const a: array of TEntry): SizeInt;
begin
  CheckInIteration;
  Result := DoAddAll(a);
end;

function TGAbstractMap.AddAll(e: IEntryEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoAddAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMap.Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoSetValue(aKey, aNewValue);
end;

function TGAbstractMap.Contains(const aKey: TKey): Boolean;
begin
  Result := Find(aKey) <> nil;
end;

function TGAbstractMap.NonContains(const aKey: TKey): Boolean;
begin
  Result := not Contains(aKey);
end;

function TGAbstractMap.ContainsAny(const a: array of TKey): Boolean;
var
  I: SizeInt;
begin
  if NonEmpty then
    for I := 0 to System.High(a) do
      if Contains(a[I]) then
        exit(True);
  Result := False;
end;

function TGAbstractMap.ContainsAny(e: IKeyEnumerable): Boolean;
begin
  if NonEmpty then
    with e.GetEnumerator do
      try
        while MoveNext do
          if Contains(Current) then
            exit(True);
      finally
        Free;
      end
  else
    e.Discard;
  Result := False;
end;

function TGAbstractMap.ContainsAll(const a: array of TKey): Boolean;
var
  I: SizeInt;
begin
  if IsEmpty then exit(System.Length(a) = 0);
  for I := 0 to System.High(a) do
    if not Contains(a[I]) then
      exit(False);
  Result := True;
end;

function TGAbstractMap.ContainsAll(e: IKeyEnumerable): Boolean;
begin
  if IsEmpty then exit(e.None);
  with e.GetEnumerator do
    try
      while MoveNext do
        if not Contains(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGAbstractMap.Remove(const aKey: TKey): Boolean;
begin
  CheckInIteration;
  Result := DoRemove(aKey);
end;

function TGAbstractMap.RemoveAll(const a: array of TKey): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveAll(a);
end;

function TGAbstractMap.RemoveAll(e: IKeyEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMap.RemoveIf(aTest: TKeyTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractMap.RemoveIf(aTest: TOnKeyTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractMap.RemoveIf(aTest: TNestKeyTest): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveIf(aTest);
end;

function TGAbstractMap.Extract(const aKey: TKey; out v: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoExtract(aKey, v);
end;

function TGAbstractMap.ExtractIf(aTest: TKeyTest): TEntryArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

function TGAbstractMap.ExtractIf(aTest: TOnKeyTest): TEntryArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

function TGAbstractMap.ExtractIf(aTest: TNestKeyTest): TEntryArray;
begin
  CheckInIteration;
  Result := DoExtractIf(aTest);
end;

procedure TGAbstractMap.RetainAll(aCollection: IKeyCollection);
begin
  Assert(aCollection = aCollection); //to supress hints
  CheckInIteration;
  DoRemoveIf(@aCollection.NonContains);
end;


function TGAbstractMap.Keys: IKeyEnumerable;
begin
  BeginIteration;
  Result := GetKeys;
end;

function TGAbstractMap.Values: IValueEnumerable;
begin
  BeginIteration;
  Result := GetValues;
end;

function TGAbstractMap.Entries: IEntryEnumerable;
begin
  BeginIteration;
  Result := GetEntries;
end;

{ TGThreadRWMap }

function TGThreadRWMap.GetCount: SizeInt;
begin
  FRWLock.BeginRead;
  try
    Result := FMap.Count;
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWMap.GetCapacity: SizeInt;
begin
  FRWLock.BeginRead;
  try
    Result := FMap.Capacity;
  finally
    FRWLock.EndRead;
  end;
end;

procedure TGThreadRWMap.BeginRead;
begin
  FRWLock.BeginRead;
end;

procedure TGThreadRWMap.BeginWrite;
begin
  FRWLock.BeginWrite;
end;

constructor TGThreadRWMap.Create(aMap: IMap; aOwnsMap: Boolean);
begin
  FRWLock := TMultiReadExclusiveWriteSynchronizer.Create;
  FMap := aMap;
  FOwnsMap := aOwnsMap;
end;

destructor TGThreadRWMap.Destroy;
begin
  FRWLock.BeginWrite;
  try
    if OwnsMap then
      FMap._GetRef.Free;
    FMap := nil;
    inherited;
  finally
    FRWLock.EndWrite;
    FRWLock.Free;
  end;
end;

function TGThreadRWMap.ReadMap: IRoMap;
begin
  FRWLock.BeginRead;
  Result := TMap(FMap._GetRef);
end;

procedure TGThreadRWMap.EndRead;
begin
  FRWLock.EndRead;
end;

function TGThreadRWMap.WriteMap: IMap;
begin
  FRWLock.BeginWrite;
  Result := FMap;
end;

procedure TGThreadRWMap.EndWrite;
begin
  FRWLock.EndWrite;
end;

function TGThreadRWMap.Add(const aKey: TKey; const aValue: TValue): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FMap.Add(aKey, aValue);
  finally
    FRWLock.EndWrite;
  end;
end;

procedure TGThreadRWMap.AddOrSetValue(const aKey: TKey; const aValue: TValue);
begin
  FRWLock.BeginWrite;
  try
    FMap.AddOrSetValue(aKey, aValue);
  finally
    FRWLock.EndWrite;
  end;
end;

function TGThreadRWMap.TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
begin
  FRWLock.BeginRead;
  try
    Result := FMap.TryGetValue(aKey, aValue);
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWMap.GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
begin
  FRWLock.BeginRead;
  try
    Result := FMap.GetValueDef(aKey, aDefault);
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWMap.Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FMap.Replace(aKey, aNewValue);
  finally
    FRWLock.EndWrite;
  end;
end;

function TGThreadRWMap.Contains(const aKey: TKey): Boolean;
begin
  FRWLock.BeginRead;
  try
    Result := FMap.Contains(aKey);
  finally
    FRWLock.EndRead;
  end;
end;

function TGThreadRWMap.Extract(const aKey: TKey; out aValue: TValue): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FMap.Extract(aKey, aValue);
  finally
    FRWLock.EndWrite;
  end;
end;

function TGThreadRWMap.Remove(const aKey: TKey): Boolean;
begin
  FRWLock.BeginWrite;
  try
    Result := FMap.Remove(aKey);
  finally
    FRWLock.EndWrite;
  end;
end;

{ TGAbstractMultiMap.TAbstractValueSet }

function TGAbstractMultiMap.TAbstractValueSet.ToArray: TValueArray;
var
  I: SizeInt;
begin
  SetLength(Result, ARRAY_INITIAL_SIZE);
  I := 0;
  with GetEnumerator do
    try
      while MoveNext do
        begin
          if I = System.Length(Result) then
            System.SetLength(Result, I * 2);
          Result[I] := Current;
          Inc(I);
        end;
    finally
      Free;
    end;
  SetLength(Result, I);
end;

{ TGAbstractMultiMap.TCustomValueEnumerable }

constructor TGAbstractMultiMap.TCustomValueEnumerable.Create(aMap: TGAbstractMultiMap);
begin
  inherited Create;
  FOwner := aMap;
end;

destructor TGAbstractMultiMap.TCustomValueEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMultiMap.TCustomEntryEnumerable }

constructor TGAbstractMultiMap.TCustomEntryEnumerable.Create(aMap: TGAbstractMultiMap);
begin
  inherited Create;
  FOwner := aMap;
end;

destructor TGAbstractMultiMap.TCustomEntryEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMultiMap.TCustomValueCursor }

constructor TGAbstractMultiMap.TCustomValueCursor.Create(e: TSpecEnumerator; aMap: TGAbstractMultiMap);
begin
  inherited Create(e);
  FOwner := aMap;
end;

destructor TGAbstractMultiMap.TCustomValueCursor.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

{ TGAbstractMultiMap }

function TGAbstractMultiMap.DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
var
  p: PMMEntry;
begin
  p := FindOrAdd(aKey);
  if p^.Values.Add(aValue) then
    begin
      Inc(FCount);
      exit(True);
    end;
  Result := False;
end;

function TGAbstractMultiMap.DoAddAll(const a: array of TEntry): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to High(a) do
    with a[I] do
      DoAdd(Key, Value);
  Result := Count - Result;
end;

function TGAbstractMultiMap.DoAddAll(e: IEntryEnumerable): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        with Current do
          DoAdd(Key, Value);
    finally
      Free;
    end;
  Result := Count - Result;
end;

function TGAbstractMultiMap.DoAddValues(const aKey: TKey; const a: array of TValue): SizeInt;
var
  p: PMMEntry;
  v: TValue;
begin
  Result := 0;
  if System.Length(a) > 0 then
    begin
      p := FindOrAdd(aKey);
      for v in a do
        Result += Ord(p^.Values.Add(v));
      FCount += Result;
    end;
end;

function TGAbstractMultiMap.DoAddValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
var
  p: PMMEntry;
begin
  Result := 0;
  p := FindOrAdd(aKey);
  with e.GetEnumerator do
    try
      while MoveNext do
        Result += Ord(p^.Values.Add(Current));
    finally
      Free;
    end;
  FCount += Result;
end;

function TGAbstractMultiMap.DoRemove(const aKey: TKey; const aValue: TValue): Boolean;
var
  p: PMMEntry;
begin
  p := Find(aKey);
  if p <> nil then
    begin
      Result := p^.Values.Remove(aValue);
      FCount -= Ord(Result);
      if p^.Values.Count = 0 then
        DoRemoveKey(aKey);
    end
  else
    Result := False;
end;

function TGAbstractMultiMap.DoRemoveAll(const a: array of TEntry): SizeInt;
var
  e: TEntry;
begin
  Result := 0;
  for e in a do
    Result += Ord(DoRemove(e.Key, e.Value));
end;

function TGAbstractMultiMap.DoRemoveAll(e: IEntryEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            with Current do
              if DoRemove(Key, Value) and (Count = 0) then
                break;
        finally
          Free;
        end;
      Result -= Count;
    end
  else
    e.Discard;
end;

function TGAbstractMultiMap.DoRemoveValues(const aKey: TKey; const a: array of TValue): SizeInt;
var
  p: PMMEntry;
  v: TValue;
begin
  p := Find(aKey);
  Result := 0;
  if p <> nil then
    begin
      for v in a do
        Result += Ord( p^.Values.Remove(v));
      FCount -= Result;
      if p^.Values.Count = 0 then
        DoRemoveKey(aKey);
    end;
end;

function TGAbstractMultiMap.DoRemoveValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
var
  p: PMMEntry;
  v: TValue;
begin
  p := Find(aKey);
  Result := 0;
  if p <> nil then
    begin
      for v in e do
        Result += Ord( p^.Values.Remove(v));
      FCount -= Result;
      if p^.Values.Count = 0 then
        DoRemoveKey(aKey);
    end
  else
    e.FindFirst(v);///////////////
end;

function TGAbstractMultiMap.DoRemoveKeys(const a: array of TKey): SizeInt;
var
  k: TKey;
begin
  Result := 0;
  for k in a do
    Result += DoRemoveKey(k);
  FCount -= Result;
end;

function TGAbstractMultiMap.DoRemoveKeys(e: IKeyEnumerable): SizeInt;
var
  k: TKey;
begin
  Result := 0;
  for k in e do
    Result += DoRemoveKey(k);
  FCount -= Result;
end;

function TGAbstractMultiMap.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGAbstractMultiMap.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGAbstractMultiMap.Clear;
begin
  CheckInIteration;
  DoClear;
  FCount := 0;
end;

procedure TGAbstractMultiMap.EnsureCapacity(aValue: SizeInt);
begin
  CheckInIteration;
  DoEnsureCapacity(aValue);
end;

procedure TGAbstractMultiMap.TrimToFit;
begin
  CheckInIteration;
  DoTrimToFit;
end;

function TGAbstractMultiMap.Contains(const aKey: TKey): Boolean;
begin
  Result := Find(aKey) <> nil;
end;

function TGAbstractMultiMap.ContainsValue(const aKey: TKey; const aValue: TValue): Boolean;
var
  p: PMMEntry;
begin
  p := Find(aKey);
  if p <> nil then
    Result := p^.Values.Contains(aValue)
  else
    Result := False;
end;

function TGAbstractMultiMap.Add(const aKey: TKey; const aValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(aKey, aValue);
end;

function TGAbstractMultiMap.Add(const e: TEntry): Boolean;
begin
  Result := Add(e.Key, e.Value);
end;

function TGAbstractMultiMap.AddAll(const a: array of TEntry): SizeInt;
begin
  CheckInIteration;
  Result := DoAddAll(a);
end;

function TGAbstractMultiMap.AddAll(e: IEntryEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoAddAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMultiMap.AddValues(const aKey: TKey; const a: array of TValue): SizeInt;
begin
  CheckInIteration;
  Result := DoAddValues(aKey, a);
end;

function TGAbstractMultiMap.AddValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
begin
  CheckInIteration;
  Result := DoAddValues(aKey, e);
end;

function TGAbstractMultiMap.Remove(const aKey: TKey; const aValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoRemove(aKey, aValue);
end;

function TGAbstractMultiMap.Remove(const e: TEntry): Boolean;
begin
  Result := Remove(e.Key, e.Value);
end;

function TGAbstractMultiMap.RemoveAll(const a: array of TEntry): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveAll(a);
end;

function TGAbstractMultiMap.RemoveAll(e: IEntryEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMultiMap.RemoveValues(const aKey: TKey; const a: array of TValue): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveValues(aKey, a);
end;

function TGAbstractMultiMap.RemoveValues(const aKey: TKey; e: IValueEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveValues(aKey, e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMultiMap.RemoveKey(const aKey: TKey): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveKey(aKey);
  FCount -= Result;
end;

function TGAbstractMultiMap.RemoveKeys(const a: array of TKey): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveKeys(a);
end;

function TGAbstractMultiMap.RemoveKeys(e: IKeyEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveKeys(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGAbstractMultiMap.ValuesView(const aKey: TKey): IValueEnumerable;
var
  p: PMMEntry;
begin
  p := Find(aKey);
  if p <> nil then
    begin
      BeginIteration;
      Result := TCustomValueCursor.Create(p^.Values.GetEnumerator, Self);
    end
  else
    Result := specialize TGArrayCursor<TValue>.Create(nil);
end;

function TGAbstractMultiMap.Keys: IKeyEnumerable;
begin
  BeginIteration;
  Result := GetKeys;
end;

function TGAbstractMultiMap.Values: IValueEnumerable;
begin
  BeginIteration;
  Result := GetValues;
end;

function TGAbstractMultiMap.Entries: IEntryEnumerable;
begin
  BeginIteration;
  Result := GetEntries;
end;

function TGAbstractMultiMap.ValueCount(const aKey: TKey): SizeInt;
var
  p: PMMEntry;
begin
  p := Find(aKey);
  if p <> nil then
    Result := p^.Values.Count
  else
    Result := 0;
end;

{ TGAbstractTable2D.TColData }

constructor TGAbstractTable2D.TColData.Create(const aRow: TRow; const aValue: TValue);
begin
  Row := aRow;
  Value := aValue;
end;

{ TGAbstractTable2D.TRowData }

constructor TGAbstractTable2D.TRowData.Create(const aCol: TCol; const aValue: TValue);
begin
  Column := aCol;
  Value := aValue;
end;

{ TGAbstractTable2D.TCustomRowMap }

function TGAbstractTable2D.TCustomRowMap.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGAbstractTable2D.TCustomRowMap.GetValueOrDefault(const aCol: TCol): TValue;
begin
  if not TryGetValue(aCol, Result) then
    Result := Default(TValue);
end;

{ TGAbstractTable2D }

function TGAbstractTable2D.GetColCount(const aRow: TRow): SizeInt;
var
  p: PRowEntry;
begin
  p := DoFindRow(aRow);
  if p <> nil then
    Result := p^.Columns.Count
  else
    Result := 0;
end;

function TGAbstractTable2D.GetRowMap(const aRow: TRow): IRowMap;
var
  p: PRowEntry;
begin
  DoFindOrAddRow(aRow, p);
  Result := p^.Columns;
end;

function TGAbstractTable2D.GetCell(const aRow: TRow; const aCol: TCol): TValue;
begin
  if not FindCell(aRow, aCol, Result) then
    raise ELGTableError.CreateFmt(SECellNotFoundFmt, [ClassName]);
end;

function TGAbstractTable2D.IsEmpty: Boolean;
begin
  Result := CellCount = 0;
end;

function TGAbstractTable2D.NonEmpty: Boolean;
begin
  Result := CellCount <> 0;
end;

function TGAbstractTable2D.ContainsRow(const aRow: TRow): Boolean;
begin
  Result := DoFindRow(aRow) <> nil;
end;

function TGAbstractTable2D.FindRow(const aRow: TRow; out aMap: IRowMap): Boolean;
var
  p: PRowEntry;
begin
  p := DoFindRow(aRow);
  Result := p <> nil;
  if Result then
    aMap := p^.Columns;
end;

function TGAbstractTable2D.FindOrAddRow(const aRow: TRow): IRowMap;
var
  p: PRowEntry;
begin
  DoFindOrAddRow(aRow, p);
  Result := p^.Columns;
end;

function TGAbstractTable2D.AddRow(const aRow: TRow): Boolean;
var
  p: PRowEntry;
begin
  Result := not DoFindOrAddRow(aRow, p);
end;

function TGAbstractTable2D.AddRows(const a: array of TRow): SizeInt;
var
  r: TRow;
begin
  Result := 0;
  for r in a do
    Result += Ord(AddRow(r));
end;

function TGAbstractTable2D.RemoveRow(const aRow: TRow): SizeInt;
begin
  Result := DoRemoveRow(aRow);
end;

function TGAbstractTable2D.RemoveColumn(const aCol: TCol): SizeInt;
var
  Map: IRowMap;
begin
  Result := 0;
  for Map in EnumRowMaps do
    Result += Ord(Map.Remove(aCol));
end;

function TGAbstractTable2D.ContainsCell(const aRow: TRow; const aCol: TCol): Boolean;
var
  p: PRowEntry;
begin
  p := DoFindRow(aRow);
  if p <> nil then
    Result := p^.Columns.Contains(aCol)
  else
    Result := False;
end;

function TGAbstractTable2D.FindCell(const aRow: TRow; const aCol: TCol; out aValue: TValue): Boolean;
var
  p: PRowEntry;
begin
  p := DoFindRow(aRow);
  if p <> nil then
    Result := p^.Columns.TryGetValue(aCol, aValue)
  else
    Result := False;
end;

function TGAbstractTable2D.GetCellDef(const aRow: TRow; const aCol: TCol; aDef: TValue): TValue;
begin
  if not FindCell(aRow, aCol, Result) then
    Result := aDef;
end;

procedure TGAbstractTable2D.AddOrSetCell(const aRow: TRow; const aCol: TCol; const aValue: TValue);
var
  p: PRowEntry;
begin
  DoFindOrAddRow(aRow, p);
  p^.Columns[aCol] := aValue;
end;

function TGAbstractTable2D.AddCell(const aRow: TRow; const aCol: TCol; const aValue: TValue): Boolean;
begin
  Result := not ContainsCell(aRow, aCol);
  if Result then
    AddOrSetCell(aRow, aCol, aValue);
end;

function TGAbstractTable2D.AddCell(const e: TCellData): Boolean;
begin
  Result := AddCell(e.Row, e.Column, e.Value);
end;

function TGAbstractTable2D.AddCells(const a: array of TCellData): SizeInt;
var
  e: TCellData;
begin
  Result := 0;
  for e in a do
    Result += Ord(AddCell(e));
end;

function TGAbstractTable2D.RemoveCell(const aRow: TRow; const aCol: TCol): Boolean;
var
  p: PRowEntry;
begin
  p := DoFindRow(aRow);
  if p <> nil then
    begin
      Result := p^.Columns.Remove(aCol);
      if Result and p^.Columns.IsEmpty then
        DoRemoveRow(aRow);
    end
  else
    Result := False;
end;

end.

