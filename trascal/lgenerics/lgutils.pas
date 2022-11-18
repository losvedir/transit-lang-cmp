{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Most common types and utils.                                            *
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
unit lgUtils;

{$MODE DELPHI}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}

interface

uses

  SysUtils,
  Math,
  lgStrConst;

type

  TSortOrder            = (soAsc, soDesc);
  TRangeBound           = (rbLow, rbHigh);
  TTriLean              = (tlFalse, tlTrue, tlUnknown);
  TRangeBounds          = set of TRangeBound;
  TDummy                = packed record end;
  TGArray<T>            = array of T;
  TGLessCompare<T>      = function(const L, R: T): Boolean;
  TGOnLessCompare<T>    = function(const L, R: T): Boolean of object;
  TGNestLessCompare<T>  = function(const L, R: T): Boolean is nested;
  TGEqualCompare<T>     = function(const L, R: T): Boolean;
  TGOnEqualCompare<T>   = function(const L, R: T): Boolean of object;
  TGNestEqualCompare<T> = function(const L, R: T): Boolean is nested;
{ predicates }
  TGTest<T>             = function(const aValue: T): Boolean;
  TGOnTest<T>           = function(const aValue: T): Boolean of object;
  TGNestTest<T>         = function(const aValue: T): Boolean is nested;
{ mappings }
  TGMapFunc<X, Y>       = function(const aValue: X): Y;
  TGOnMap<X, Y>         = function(const aValue: X): Y of object;
  TGNestMap<X, Y>       = function(const aValue: X): Y is nested;
{ callbacks }
  TGUnaryProc<T>        = procedure(const aValue: T);
  TGUnaryMethod<T>      = procedure(const aValue: T) of object;
  TGNestUnaryProc<T>    = procedure(const aValue: T) is nested;
{ foldings; note: accumulator on second position }
  TGFold<X, Y>          = function(const L: X; const R: Y): Y;
  TGOnFold<X, Y>        = function(const L: X; const R: Y): Y of object;
  TGNestFold<X, Y>      = function(const L: X; const R: Y): Y is nested;

  TGSortProc<T>         = procedure(var A: array of T; o: TSortOrder = soAsc);

  ELGCapacityExceed     = class(Exception);
  ELGAccessEmpty        = class(Exception);
  ELGOptional           = class(Exception);
  ELGFuture             = class(Exception);
  ELGUpdateLock         = class(Exception);
  ELGListError          = class(Exception);
  ELGMapError           = class(Exception);
  ELGTableError         = class(Exception);

const
  MAX_CONTAINER_SIZE         = Succ(High(SizeInt) shr 2);
  ARRAY_INITIAL_SIZE         = 8;// * must be power of 2 *
  DEFAULT_CONTAINER_CAPACITY = 8;// * must be power of 2 *
  BOUNDS_BOTH                = TRangeBounds([rbLow, rbHigh]);
  WAIT_INFINITE              = -1;
  {$PUSH}{$J-}
  NULL_INDEX: SizeInt        = SizeInt(-1);
  {$POP}
  VOID: TDummy               = ();

type
  TGOptional<T> = record
  private
  var
    FValue: T;
    FAssigned: Boolean;
  class var
    CFTypeKind: System.TTypeKind;
    CFNilable: Boolean;
  const
    NilableKinds = [System.tkMethod, System.tkInterface, System.tkClass, System.tkInterfaceRaw,
                    System.tkProcVar, System.tkClassRef, System.tkPointer];
    function GetValue: T;
    class constructor InitTypeInfo;
    class function IsNil(const aValue): Boolean; static;
    class operator Initialize(var o: TGOptional<T>); inline;
  public
    class operator Implicit(const aValue: T): TGOptional<T>; inline;
    class operator Implicit(const o: TGOptional<T>): T; inline;
    class operator Explicit(const o: TGOptional<T>): T; inline;
    procedure Assign(const aValue: T);
    function  OrElse(const aValue: T): T; inline;
    function  OrElseRaise(e: ExceptClass; const aMsg: string = ''): T; inline;
    property  Assigned: Boolean read FAssigned;
    property  Value: T read GetValue;
    class property Nilable: Boolean read CFNilable;
  end;

  { TGAutoRef: an easy way to get an instance of a class limited lifetime;
    An instance owned by TGAutoRef will be automatically created upon first request
    and will automatically be destroyed upon leaving the scope;
    class T must provide default parameterless constructor;
    copying a record will raise EInvalidOpException }
  TGAutoRef<T: class, constructor> = record
  strict private
    FInstance: T;
    FOwnsInstance: Boolean;
    function  GetInstance: T;
    procedure SetInstance(aValue: T); inline;
    function  Release: T;
    class operator Initialize(var a: TGAutoRef<T>); inline;
    class operator Finalize(var a: TGAutoRef<T>); inline;
    class operator Copy(constref aSrc: TGAutoRef<T>; var aDst: TGAutoRef<T>);
    class operator AddRef(var a: TGAutoRef<T>); inline;
  public
  type
    TInstance = T;
    class operator Implicit(var a: TGAutoRef<T>): T; inline;
    class operator Explicit(var a: TGAutoRef<T>): T; inline;
    function  HasInstance: Boolean; inline;
  { frees the instance it owns }
    procedure Clear; inline;
  { returns the instance it owns and stops ownership }
    function  ReleaseInstance: T; inline;
  { transfers ownership of an instance to aRef;
    will raise EInvalidOpException if it does not own the instance }
    procedure OwnMove(var aRef: TGAutoRef<T>);
    property  Instance: T read GetInstance write SetInstance;
    property  OwnsInstance: Boolean read FOwnsInstance;
  end;

  { TGUniqRef: like TGAutoRef provides a class instance with a limited lifetime,
    it does not require T to have a parameterless constructor, and does not automatically
    create an instance; copying a record will raise EInvalidOpException }
  TGUniqRef<T: class> = record
  strict private
    FInstance: T;
    FOwnsInstance: Boolean;
    procedure SetInstance(aValue: T); inline;
    function  Release: T;
    class operator Initialize(var u: TGUniqRef<T>); inline;
    class operator Finalize(var u: TGUniqRef<T>); inline;
    class operator Copy(constref aSrc: TGUniqRef<T>; var aDst: TGUniqRef<T>);
    class operator AddRef(var u: TGUniqRef<T>); inline;
  public
  type
    TInstance = T;
    class operator Implicit(var u: TGUniqRef<T>): T; inline;
    class operator Explicit(var u: TGUniqRef<T>): T; inline;
    function  HasInstance: Boolean; inline;
  { frees the instance it owns }
    procedure Clear; inline;
  { returns the instance it owns and stops ownership }
    function  ReleaseInstance: T; inline;
  { transfers ownership of an instance to aRef;
    will raise EInvalidOpException if it does not own the instance }
    procedure OwnMove(var aRef: TGUniqRef<T>);
    property  Instance: T read FInstance write SetInstance;
    property  OwnsInstance: Boolean read FOwnsInstance;
  end;

  { TGSharedAutoRef: intended to share a single instance of T by multiple entities using ARC,
    the instance will be automatically destroyed when the reference count becomes zero;
    to automatically create an instance, class T must provide default parameterless constructor }
  TGSharedAutoRef<T: class, constructor> = record
  private
    FInstance: T;
    FRefCount: PInteger;
    procedure InitInstance(aValue: T);
    function  GetInstance: T;
    function  GetRefCount: Integer; inline;
    procedure SetInstance(aValue: T);
    class operator Initialize(var s: TGSharedAutoRef<T>); inline;
    class operator Finalize(var s: TGSharedAutoRef<T>);
    class operator Copy(constref aSrc: TGSharedAutoRef<T>; var aDst: TGSharedAutoRef<T>); inline;
    class operator AddRef(var s: TGSharedAutoRef<T>); inline;
  public
  type
    TInstance = T;
    class operator Implicit(var s: TGSharedAutoRef<T>): T; inline;
    class operator Explicit(var s: TGSharedAutoRef<T>): T; inline;
    function  HasInstance: Boolean; inline;
    procedure Release;
    property  RefCount: Integer read GetRefCount;
    property  Instance: T read GetInstance write SetInstance;
  end;

  { TGSharedRef: like TGSharedAutoRef intended to share a single instance of T by multiple
    entities using ARC; it does not require T to have a parameterless constructor and does not
    automatically create an instance }
  TGSharedRef<T: class> = record
  private
    FInstance: T;
    FRefCount: PInteger;
    procedure InitInstance(aValue: T);
    function  GetInstance: T;
    function  GetRefCount: Integer; inline;
    procedure SetInstance(aValue: T);
    class operator Initialize(var s: TGSharedRef<T>); inline;
    class operator Finalize(var s: TGSharedRef<T>);
    class operator Copy(constref aSrc: TGSharedRef<T>; var aDst: TGSharedRef<T>); inline;
    class operator AddRef(var s: TGSharedRef<T>); inline;
  public
  type
    TInstance = T;
    class operator Implicit(var s: TGSharedRef<T>): T; inline;
    class operator Explicit(var s: TGSharedRef<T>): T; inline;
    function  HasInstance: Boolean; inline;
    procedure Release;
    property  RefCount: Integer read GetRefCount;
    property  Instance: T read GetInstance write SetInstance;
  end;

  { TGUniqPtr }
  TGUniqPtr<T> = record
  public
  type
    PValue = ^T;
  private
    FPtr: PValue;
    FOwnsPtr: Boolean;
    function  GetAllocated: Boolean; inline;
    function  GetPtr: PValue;
    procedure FreePtr; inline;
    function  GetValue: T; inline;
    procedure SetValue(const aValue: T); inline;
    class operator Initialize(var u: TGUniqPtr<T>); inline;
    class operator Finalize(var u: TGUniqPtr<T>); inline;
    class operator Copy(constref aSrc: TGUniqPtr<T>; var aDst: TGUniqPtr<T>);
    class operator AddRef(var u: TGUniqPtr<T>); inline;
  public
    class operator Implicit(var u: TGUniqPtr<T>): T; inline;
    class operator Explicit(var u: TGUniqPtr<T>): T; inline;
    procedure Clear;
    procedure OwnMove(var aPtr: TGUniqPtr<T>);
    property  Allocated: Boolean read GetAllocated;
    property  Ptr: PValue read GetPtr;
    property  OwnsPtr: Boolean read FOwnsPtr;
    property  Value: T read GetValue write SetValue;
  end;

  { TGCowPtr: provides an ARC pointer to data on the heap with copy-on-write semantics(if necessary) }
  TGCowPtr<T> = record
  public
  type
    PValue = ^T;
  private
  type
    TInstance = record
      Value: T;
      RefCount: Integer;
    end;
    PInstance = ^TInstance;
  var
    FInstance: PInstance;
    function  NewInstance: PInstance;
    procedure ReleaseInstance;
    function  GetAllocated: Boolean; inline;
    function  GetRefCount: Integer;
    function  GetPtr: PValue;
    function  GetUniqPtr: PValue;
    function  GetValue: T; inline;
    procedure SetValue(const aValue: T); inline;
    class operator Initialize(var cp: TGCowPtr<T>); inline;
    class operator Finalize(var cp: TGCowPtr<T>); inline;
    class operator Copy(constref aSrc: TGCowPtr<T>; var aDst: TGCowPtr<T>);
    class operator AddRef(var cp: TGCowPtr<T>); inline;
  public
    class operator Implicit(var cp: TGCowPtr<T>): T; inline;
    class operator Explicit(var cp: TGCowPtr<T>): T; inline;
    procedure Release;
  { ensures that the current ref is unique }
    procedure Unique;
    property  Allocated: Boolean read GetAllocated;
    property  RefCount: Integer read GetRefCount;
  { use Ptr to read data value, or to write/modify data value if COW is not required }
    property  Ptr: PValue read GetPtr;
  { use UniqPtr to write/modify data value if COW is required }
    property  UniqPtr: PValue read GetUniqPtr;
  { SetValue always uses COW }
    property  Value: T read GetValue write SetValue;
  end;

  { TGCowDynArray: ARC dynamic array with copy-on-write semantics(if necessary) }
  TGCowDynArray<T> = record
  type
    PItem = ^T;
  private
  type
    TInstance = record
      FItems: PItem;
      FLength: SizeInt;
      FRefCount: Integer;
    end;
    PInstance = ^TInstance;
    PArray    = ^TGCowDynArray<T>;
  var
    FInstance: PInstance;
    function  NewInstance: PInstance; inline;
    procedure UniqInstance;
    procedure ReallocUniq(aNewLen: SizeInt);
    procedure Realloc(aNewLen: SizeInt);
    procedure ReallocManaged(aNewLen: SizeInt);
    function  GetLength: SizeInt; inline;
    function  GetRefCount: Integer; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetPtr: PItem; inline;
    function  GetUniqPtr: PItem;
    procedure SetLen(aValue: SizeInt);
    procedure SetItem(aIndex: SizeInt; const aValue: T); inline;
    function  GetHigh: SizeInt; inline;
    class procedure FillItems(aFrom: PItem; aCount: SizeInt; const aValue: T); static;
    class procedure CopyItems(aSrc, aDst: PItem; aCount: SizeInt); static;
    class operator  Initialize(var a: TGCowDynArray<T>); inline;
    class operator  Finalize(var a: TGCowDynArray<T>); inline;
    class operator  Copy(constref aSrc: TGCowDynArray<T>; var aDst: TGCowDynArray<T>);
    class operator  AddRef(var a: TGCowDynArray<T>); inline;
  public
  type
    TEnumerator = record
    private
      FCurrent,
      FLast: PItem;
      function GetCurrent: T; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrent,
      FFirst: PItem;
      function GetCurrent: T; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FArray: PArray;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  private
    function  GetReverseEnumerator: TReverseEnumerator;
  public
    function  GetEnumerator: TEnumerator;
    function  Reverse: TReverse; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Release;
  { ensures that the current instance is unique }
    procedure Unique;
  { sets length to aCount and fills array by aCount values aValue }
    procedure Fill(aCount: SizeInt; const aValue: T);
    function  CreateCopy(aFromIndex, aCount: SizeInt): TGCowDynArray<T>;
    property  RefCount: Integer read GetRefCount;
    property  Length: SizeInt read GetLength write SetLen;
    property  High: SizeInt read GetHigh;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Ptr: PItem read GetPtr;
    property  UniqPtr: PItem read GetUniqPtr;
  end;

  { TGDynArray: dynamic array without ARC, it pretends to be a value type }
  TGDynArray<T> = record
  type
    PItem = ^T;
  private
    FItems: PItem;
    FLength: SizeInt;
    procedure FillItems(aFrom: PItem; aCount: SizeInt; constref aValue: T);
    procedure ReallocManaged(aNewLen: SizeInt);
    procedure SetLen(aValue: SizeInt);
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); inline;
    function  GetHigh: SizeInt; inline;
    class procedure CopyItems(aSrc, aDst: PItem; aCount: SizeInt); static;
    class operator  Initialize(var a: TGDynArray<T>); inline;
    class operator  Finalize(var a: TGDynArray<T>); inline;
    class operator  Copy(constref aSrc: TGDynArray<T>; var aDst: TGDynArray<T>);
    class operator  AddRef(var a: TGDynArray<T>);
  public
  type
    TEnumerator = record
    private
      FCurrent,
      FLast: PItem;
      function GetCurrent: T; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrent,
      FFirst: PItem;
      function GetCurrent: T; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FArray: ^TGDynArray<T>;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

    TMutableEnumerator = record
    private
      FCurrent,
      FLast: PItem;
    public
      function MoveNext: Boolean; inline;
      property Current: PItem read FCurrent;
    end;

    TMutables = record
    private
      FArray: ^TGDynArray<T>;
    public
      function GetEnumerator: TMutableEnumerator; inline;
    end;

  public
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  Mutables: TMutables; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
  { sets length to aCount and fills array by aCount values aValue }
    procedure Fill(aCount: SizeInt; constref aValue: T);
    function  CreateCopy(aFromIndex, aCount: SizeInt): TGDynArray<T>;
    procedure Clear;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Length: SizeInt read FLength write SetLen;
    property  High: SizeInt read GetHigh;
    property  Ptr: PItem read FItems;
  end;

  TGEnumerator<T> = class abstract
  protected
    function  GetCurrent: T; virtual; abstract;
  public
    function  MoveNext: Boolean; virtual; abstract;
    procedure Reset; virtual; abstract;
    property  Current: T read GetCurrent;
  end;

{$PUSH}{$INTERFACES COM}
  ITask = interface
  ['{896FB5A3-4993-4698-9C33-D538A3BEE876}']
    procedure Execute;
  end;

  TTaskPriority = (tapLowest, tapBelowNormal, tapNormal, tapAboveNormal, tapHighest);

  IPriorityTask = interface(ITask)
  ['{24E2498F-3849-4995-9FEC-D82F90D34B1F}']
    function GetPriority: TTaskPriority;
  end;
{$POP}

{$PUSH}{$INTERFACES CORBA}
  IObjInstance = interface
  ['{B5EABEA2-FF39-4B4A-AF2B-3B8603F0C575}']
    function _GetRef: TObject;
  end;

  IGEnumerable<T> = interface(IObjInstance)
  ['{92F9FDFC-BEA4-4968-A033-7A90C05DDA60}']
    function  GetEnumerator: TGEnumerator<T>;
  { If any method of the IGEnumerable instance is not called, there will be a memory leak;
    just call Discard for preventing this }
    procedure Discard;
  { enumerates elements in reverse order }
    function  Reverse: IGEnumerable<T>;
    function  ToArray: TGArray<T>;
    function  Any: Boolean; overload;
    function  None: Boolean;  overload;
    function  Total: SizeInt; overload;
    function  FindFirst(out aValue: T): Boolean;
    function  First: TGOptional<T>;
    function  FindLast(out aValue: T): Boolean;
    function  Last: TGOptional<T>;
    function  FindMin(out aValue: T; c: TGLessCompare<T>): Boolean; overload;
    function  FindMin(out aValue: T; c: TGOnLessCompare<T>): Boolean; overload;
    function  FindMin(out aValue: T; c: TGNestLessCompare<T>): Boolean; overload;
    function  Min(c: TGLessCompare<T>): TGOptional<T>; overload;
    function  Min(c: TGOnLessCompare<T>): TGOptional<T>; overload;
    function  Min(c: TGNestLessCompare<T>): TGOptional<T>; overload;
    function  FindMax(out aValue: T; c: TGLessCompare<T>): Boolean; overload;
    function  FindMax(out aValue: T; c: TGOnLessCompare<T>): Boolean; overload;
    function  FindMax(out aValue: T; c: TGNestLessCompare<T>): Boolean; overload;
    function  Max(c: TGLessCompare<T>): TGOptional<T>; overload;
    function  Max(c: TGOnLessCompare<T>): TGOptional<T>; overload;
    function  Max(c: TGNestLessCompare<T>): TGOptional<T>; overload;
    function  Skip(aCount: SizeInt): IGEnumerable<T>;
    function  SkipWhile(p: TGTest<T>): IGEnumerable<T>; overload;
    function  SkipWhile(p: TGOnTest<T>): IGEnumerable<T>; overload;
    function  SkipWhile(p: TGNestTest<T>): IGEnumerable<T>; overload;
    function  Limit(aCount: SizeInt): IGEnumerable<T>;
    function  TakeWhile(p: TGTest<T>): IGEnumerable<T>; overload;
    function  TakeWhile(p: TGOnTest<T>): IGEnumerable<T>; overload;
    function  TakeWhile(p: TGNestTest<T>): IGEnumerable<T>; overload;
    function  Sorted(c: TGLessCompare<T>; aStable: Boolean = False): IGEnumerable<T>; overload;
    function  Sorted(c: TGOnLessCompare<T>; aStable: Boolean = False): IGEnumerable<T>; overload;
    function  Sorted(c: TGNestLessCompare<T>; aStable: Boolean = False): IGEnumerable<T>; overload;
    function  Sorted(aProc: TGSortProc<T>; o: TSortOrder = soAsc): IGEnumerable<T>; overload;
    function  Select(p: TGTest<T>): IGEnumerable<T>; overload;
    function  Select(p: TGOnTest<T>): IGEnumerable<T>; overload;
    function  Select(p: TGNestTest<T>): IGEnumerable<T>; overload;
    function  Any(p: TGTest<T>): Boolean; overload;
    function  Any(p: TGOnTest<T>): Boolean; overload;
    function  Any(p: TGNestTest<T>): Boolean; overload;
    function  None(p: TGTest<T>): Boolean; overload;
    function  None(p: TGOnTest<T>): Boolean; overload;
    function  None(p: TGNestTest<T>): Boolean; overload;
    function  All(p: TGTest<T>): Boolean; overload;
    function  All(p: TGOnTest<T>): Boolean; overload;
    function  All(p: TGNestTest<T>): Boolean; overload;
    function  Total(p: TGTest<T>): SizeInt; overload;
    function  Total(p: TGOnTest<T>): SizeInt; overload;
    function  Total(p: TGNestTest<T>): SizeInt; overload;
    function  Distinct(c: TGLessCompare<T>): IGEnumerable<T>; overload;
    function  Distinct(c: TGOnLessCompare<T>): IGEnumerable<T>; overload;
    function  Distinct(c: TGNestLessCompare<T>): IGEnumerable<T>; overload;
    function  Map(f: TGMapFunc<T, T>): IGEnumerable<T>; overload;
    function  Map(f: TGOnMap<T, T>): IGEnumerable<T>; overload;
    function  Map(f: TGNestMap<T, T>): IGEnumerable<T>; overload;
    procedure ForEach(aCallback: TGUnaryProc<T>); overload;
    procedure ForEach(aCallback: TGUnaryMethod<T>); overload;
    procedure ForEach(aCallback: TGNestUnaryProc<T>); overload;
  { left-associative linear fold }
    function  Fold(f: TGFold<T, T>; const v0: T): T; overload;
    function  Fold(f: TGFold<T, T>): TGOptional<T>; overload;
    function  Fold(f: TGOnFold<T, T>; const v0: T): T; overload;
    function  Fold(f: TGOnFold<T, T>): TGOptional<T>; overload;
    function  Fold(f: TGNestFold<T, T>; const v0: T): T; overload;
    function  Fold(f: TGNestFold<T, T>): TGOptional<T>; overload;
  end;

  IGContainer<T> = interface(IGEnumerable<T>)
  ['{A3F04344-421D-4678-8A88-42AF65647525}']
    function  GetCount: SizeInt;
    function  GetCapacity: SizeInt;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure Clear;
    procedure EnsureCapacity(aValue: SizeInt);
  { free unused memory if possible }
    procedure TrimToFit;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  IGStack<T> = interface(IGContainer<T>)
  ['{6057A96E-1953-49CE-A81A-DF5633BCB38C}']
    procedure Push(const aValue: T);
    function  PushAll(const a: array of T): SizeInt; overload;
    function  PushAll(e: IGEnumerable<T>): SizeInt; overload;
  { EXTRACTS element from the top of stack }
    function  Pop: T;
    function  TryPop(out aValue: T): Boolean;
    function  Peek: T;
    function  TryPeek(out aValue: T): Boolean;
  end;

  IGQueue<T> = interface(IGContainer<T>)
  ['{913AFB4A-7D2C-46D8-A4FD-DAEC1F80D6C2}']
  { puts element in the tail of the queue }
    procedure Enqueue(const aValue: T);
    function  EnqueueAll(const a: array of T): SizeInt; overload;
    function  EnqueueAll(e: IGEnumerable<T>): SizeInt; overload;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T;
    function  TryDequeue(out aValue: T): Boolean;
  { examines element in the head of queue }
    function  Peek: T;
    function  TryPeek(out aValue: T): Boolean;
  end;

  THandle = type SizeUInt;

const
  INVALID_HANDLE = THandle(-1);

type

  IGPriorityQueue<T> = interface(IGQueue<T>)
  ['{39ADFF1D-018D-423B-A16A-8942B06D0A76}']
    function  Insert(const aValue: T): THandle;
    function  PeekHandle: THandle;
    function  TryPeekHandle(out aValue: THandle): Boolean;
    function  ValueOf(h: THandle): T;
    procedure Update(h: THandle; const aValue: T);
    function  Remove(h: THandle): T;
  { only another entity can be merged, aQueue will be cleared after Merge }
    function  Merge(aQueue: IGPriorityQueue<T>): SizeInt;
  end;

  IGDeque<T> = interface(IGContainer<T>)
  ['{0D127C9E-9706-4D9A-A64C-A70844DC1F55}']
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure PushFirst(const aValue: T);
    function  PushAllFirst(const a: array of T): SizeInt; overload;
    function  PushAllFirst(e: IGEnumerable<T>): SizeInt; overload;
    procedure PushLast(const aValue: T);
    function  PushAllLast(const a: array of T): SizeInt; overload;
    function  PushAllLast(e: IGEnumerable<T>): SizeInt; overload;
  { EXTRACTS element from the head of deque }
    function  PopFirst: T;
    function  TryPopFirst(out aValue: T): Boolean;
  { EXTRACTS element from the tail of deque }
    function  PopLast: T;
    function  TryPopLast(out aValue: T): Boolean;
  { examines element in the head of deque }
    function  PeekFirst: T;
    function  TryPeekFirst(out aValue: T): Boolean;
  { examines element in the tail of deque }
    function  PeekLast: T;
    function  TryPeekLast(out aValue: T): Boolean;
  { inserts aValue into position aIndex }
    procedure Insert(aIndex: SizeInt; const aValue: T);
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
  { extracts value from position aIndex }
    function  Extract(aIndex: SizeInt): T;
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
  { deletes value in position aIndex }
    procedure Delete(aIndex: SizeInt);
    function  TryDelete(aIndex: SizeInt): Boolean;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

  IGCollection<T> = interface(IGContainer<T>)
  ['{53197613-B1FC-46BD-923A-A602D0545330}']
  { returns True if element added }
    function  Add(const aValue: T): Boolean;
    function  Contains(const aValue: T): Boolean;
    function  NonContains(const aValue: T): Boolean;
    function  ContainsAny(const a: array of T): Boolean; overload;
    function  ContainsAny(e: IGEnumerable<T>): Boolean; overload;
    function  ContainsAll(const a: array of T): Boolean; overload;
    function  ContainsAll(e: IGEnumerable<T>): Boolean; overload;
    function  Extract(const aValue: T): Boolean;
  { returns True if element removed }
    function  Remove(const aValue: T): Boolean;
  { returns count of removed elements }
    function  RemoveAll(const a: array of T): SizeInt; overload;
  { returns count of removed elements }
    function  RemoveAll(e: IGEnumerable<T>): SizeInt; overload;
  { will contain only those elements that are simultaneously contained in self and c }
    procedure RetainAll(c: IGCollection<T>);
  end;

  IGReadOnlyCollection<T> = interface(IGEnumerable<T>)
  ['{D0DDB482-819A-438B-BF33-B6EF21A6A9A5}']
    function  GetCount: SizeInt;
    function  GetCapacity: SizeInt;
    function  IsEmpty: Boolean;
    function  Contains(const aValue: T): Boolean;
    function  NonContains(const aValue: T): Boolean;
    function  ContainsAny(const a: array of T): Boolean; overload;
    function  ContainsAny(e: IGEnumerable<T>): Boolean; overload;
    function  ContainsAll(const a: array of T): Boolean; overload;
    function  ContainsAll(e: IGEnumerable<T>): Boolean; overload;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  TGMapEntry<TKey, TValue> = record
    Key: TKey;
    Value: TValue;
    constructor Create(constref aKey: TKey; constref aValue: TValue);
  end;

  TMapObjectOwns   = (moOwnsKeys, moOwnsValues);
  TMapObjOwnership = set of TMapObjectOwns;

const
  OWNS_BOTH = [moOwnsKeys, moOwnsValues];

type
  TGMultiSetEntry<T> = record
    Key: T;
    Count: SizeInt;
  end;

  TGCell2D<TRow, TCol, TValue> = record
    Row:    TRow;
    Column: TCol;
    Value:  TValue;
    constructor Create(const aRow: TRow; const aCol: TCol; const aValue: TValue);
  end;

  IGMap<TKey, TValue> = interface{(IGContainer<TGMapEntry<TKey, TValue>>)}
  ['{67DBDBD2-D54C-4E6E-9BE6-ACDA0A40B63F}']
    function  _GetRef: TObject;
    function  GetCount: SizeInt;
    function  GetCapacity: SizeInt;
    function  GetValue(const aKey: TKey): TValue;
    function  IsEmpty: Boolean;
    procedure Clear;
    procedure EnsureCapacity(aValue: SizeInt);
  { free unused memory if possible }
    procedure TrimToFit;
  { returns True and add TEntry(aKey, aValue) only if not contains aKey }
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;
    procedure AddOrSetValue(const aKey: TKey; const aValue: TValue);
    function  TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
    function  GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
  { returns True and map aNewValue to aKey only if contains aKey, False otherwise }
    function  Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
    function  Contains(const aKey: TKey): Boolean;
    function  NonContains(const aKey: TKey): Boolean;
    function  Extract(const aKey: TKey; out aValue: TValue): Boolean;
    function  Remove(const aKey: TKey): Boolean;
    procedure RetainAll(aCollection: IGCollection<TKey>);
    function  Keys: IGEnumerable<TKey>;
    function  Values: IGEnumerable<TValue>;
    function  Entries: IGEnumerable<TGMapEntry<TKey, TValue>>;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  { reading will raise exception if an aKey is not present in map }
    property  Items[const aKey: TKey]: TValue read GetValue write AddOrSetValue; default;
  end;

  IGReadOnlyMap<TKey, TValue> = interface
  ['{08561616-8E8B-4DBA-AEDB-DE14C5FA9403}']
    function  GetCount: SizeInt;
    function  GetCapacity: SizeInt;
    function  IsEmpty: Boolean;
    function  TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
    function  GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
    function  Contains(const aKey: TKey): Boolean;
    function  NonContains(const aKey: TKey): Boolean;
    function  Keys: IGEnumerable<TKey>;
    function  Values: IGEnumerable<TValue>;
    function  Entries: IGEnumerable<TGMapEntry<TKey, TValue>>;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;
{$POP}

  { TGNodeManager: TNode must provide read-write property NextLink: PNode }
  TGNodeManager<TNode> = class
  public
  type
    PNode = ^TNode;
  private
    FHead: PNode;
    FFreeCount: SizeInt;
    procedure Put2FreeList(aNode: PNode); inline;
    class function CreateNode: PNode; static; inline;
    property Head: PNode read FHead;
  public
    destructor Destroy; override;
    function  NewNode: PNode;
    procedure DisposeNode(aNode: PNode); inline;
    procedure FreeNode(aNode: PNode);
    procedure EnsureFreeCount(aCount: SizeInt);
    procedure ClearFreeList;
    procedure Clear; inline;
    property  FreeCount: SizeInt read FFreeCount;
  end;

  { TGPageNodeManager: TNode must provide read-write property NextLink: PNode}
  TGPageNodeManager<TNode> = class
  public
  type
    PNode = ^TNode;

  private
  const
    PAGE_SIZE      = 4096;
    NODE_SIZE      = SizeOf(TNode);
    NODES_PER_PAGE = (PAGE_SIZE - SizeOf(Pointer)) div NODE_SIZE;

  type
    PPage = ^TPage;
    TPage = record
      Nodes: array[1..NODES_PER_PAGE] of TNode;
      NextPage: PPage;
    end;

  var
    FPageListHead: PPage;
    FFreeListHead: PNode;
    FFreeCount,
    FPageCount: SizeInt;
    procedure NewPage;
  public
    destructor Destroy; override;
    function  NewNode: PNode;
    procedure DisposeNode(aNode: PNode);
    procedure FreeNode(aNode: PNode);
    procedure EnsureFreeCount(aCount: SizeInt);
    procedure ClearFreeList;
    procedure Clear;
    property  FreeCount: SizeInt read FFreeCount;
    property  PagesAllocated: SizeInt read FPageCount;
  end;

  { TGJoinableNodeManager: TNode must provide read-write property NextLink: PNode }
  TGJoinableNodeManager<TNode> = record
  public
  type
    PNode = ^TNode;

  private
    FHead,
    FTail: PNode;
    FFreeCount: SizeInt;
    procedure Put2FreeList(aNode: PNode); inline;
    class function CreateNode: PNode; static; inline;
    class operator Finalize(var nm: TGJoinableNodeManager<TNode>);
  public
    function  NewNode: PNode;
    procedure DisposeNode(aNode: PNode); inline;
    procedure FreeNode(aNode: PNode);
    procedure EnsureFreeCount(aCount: SizeInt);
    procedure ClearFreeList;
    procedure Clear; inline;
    procedure Join(var nm: TGJoinableNodeManager<TNode>);
    property  FreeCount: SizeInt read FFreeCount;
  end;

  TGTuple2<T1, T2> = record
    F1: T1;
    F2: T2;
    constructor Create(const v1: T1; const v2: T2);
  end;

  TGTuple3<T1, T2, T3> = record
    F1: T1;
    F2: T2;
    F3: T3;
    constructor Create(const v1: T1; const v2: T2; const v3: T3);
  end;

  TGTuple4<T1, T2, T3, T4> = record
    F1: T1;
    F2: T2;
    F3: T3;
    F4: T4;
    constructor Create(const v1: T1; const v2: T2; const v3: T3; const v4: T4);
  end;

  TGTuple5<T1, T2, T3, T4, T5> = record
    F1: T1;
    F2: T2;
    F3: T3;
    F4: T4;
    F5: T5;
    constructor Create(const v1: T1; const v2: T2; const v3: T3; const v4: T4; const v5: T5);
  end;

  { TGAddMonoid uses Default(T) as identity;
    it assumes T has defined operator "+" }
  TGAddMonoid<T> = class
  private
    class function GetIdentity: T; static; inline;
  public
    class property Identity: T read GetIdentity;
    class function BinOp(const L, R: T): T; static; inline;
  end;

  { TGAddMonoidEx uses Default(T) as ZeroConst;
    it assumes T also has defined operators "=" and "*" by SizeInt }
  TGAddMonoidEx<T> = class(TGAddMonoid<T>)
  private
    class function GetZeroConst: T; static; inline;
  public
    class function AddConst(const aValue, aConst: T; aSize: SizeInt = 1): T; static; inline;
    class function IsZeroConst(const aValue: T): Boolean; static; inline;
    class property ZeroConst: T read GetZeroConst;
  end;

  { TGMaxMonoid uses T.MinValue as negative infinity;
    it assumes T has defined operator "<"  }
  TGMaxMonoid<T> = class
  private
    class function GetIdentity: T; static; inline;
  public
    class property Identity: T read GetIdentity;
    class function BinOp(const L, R: T): T; static; inline;
  end;

  { TGMaxMonoidEx uses Default(T) as ZeroConst;
    it assumes T has defined operators "=" and "+"  }
  TGMaxMonoidEx<T> = class(TGMaxMonoid<T>)
  private
    class function GetZeroConst: T; static; inline;
  public
    class function AddConst(const aValue, aConst: T; aSize: SizeInt = 1): T; static; inline;
    class function IsZeroConst(const aValue: T): Boolean; static; inline;
    class property ZeroConst: T read GetZeroConst;
  end;

  { TGMinMonoid uses T.MaxValue as infinity;
    it assumes T has defined operator "<" }
  TGMinMonoid<T> = class
  private
    class function GetIdentity: T; static; inline;
  public
    class property Identity: T read GetIdentity;
    class function BinOp(const L, R: T): T; static; inline;
  end;

  { TGMinMonoidEx uses Default(T) as ZeroConst;
    it assumes T has defined operators "=" and "+" }
  TGMinMonoidEx<T> = class(TGMinMonoid<T>)
  private
    class function GetZeroConst: T; static; inline;
  public
    class function AddConst(const aValue, aConst: T; aSize: SizeInt = 1): T; static; inline;
    class function IsZeroConst(const aValue: T): Boolean; static; inline;
    class property ZeroConst: T read GetZeroConst;
  end;

  { TGMaxPos uses T.MinValue as negative infinity;
    it assumes T has defined operator "<" }
  TGMaxPos<T>  = record
  private
     class function GetIdentity: TGMaxPos<T>; static; inline;
  public
    Value: T;
    Index: SizeInt;
    class property Identity: TGMaxPos<T> read GetIdentity;
    class function BinOp(const L, R: TGMaxPos<T>): TGMaxPos<T>; static; inline;
  end;

  { TGMinPos uses T.MaxValue as infinity;
    it assumes T has defined operator "<" }
  TGMinPos<T>  = record
  private
     class function GetIdentity: TGMinPos<T>; static; inline;
  public
    Value: T;
    Index: SizeInt;
    class property Identity: TGMinPos<T> read GetIdentity;
    class function BinOp(const L, R: TGMinPos<T>): TGMinPos<T>; static; inline;
  end;

{$PUSH}{$PACKRECORDS DEFAULT}
  TSpinLock = record
  strict private
  const
    CACHE_PAD_SIZE = 15;
  var
    FState: DWord;
    FCacheLinePad: array[1..CACHE_PAD_SIZE] of DWord;
    class operator Initialize(var sl: TSpinLock);
  public
    procedure Lock; inline;
    procedure LockTts;
    function  TryLock: Boolean; inline;
    procedure Unlock; inline;
  end;
{$POP}

const
{$IF DEFINED(CPU64)}
  INT_SIZE_LOG  = 6;
  INT_SIZE_MASK = 63;
{$ELSEIF DEFINED(CPU32)}
  INT_SIZE_LOG  = 5;
  INT_SIZE_MASK = 31;
{$ELSE}
  INT_SIZE_LOG  = 4;
  INT_SIZE_MASK = 15;
{$ENDIF}
  MAX_POSITIVE_POW2 = Succ(High(SizeInt) shr 1);

  function  BsfSizeUInt(aValue: SizeUInt): ShortInt; inline;
  function  BsrSizeUInt(aValue: SizeUInt): ShortInt; inline;
  function  RolSizeInt(aValue: SizeInt; aDist: Byte): SizeInt; inline;
  function  RorSizeInt(aValue: SizeInt; aDist: Byte): SizeInt; inline;
  { returns number of significant bits of aValue }
  function  NSB(aValue: SizeUInt): SizeInt; inline;
  function  IsTwoPower(aValue: SizeUInt): Boolean; inline;
  { warning: if aValue > MAX_POSITIVE_POW2 then function will return wrong result }
  function  RoundUpTwoPower(aValue: SizeInt): SizeInt;
  { returns the product L * R if there was no overflow during the multiplication,
    otherwise returns High(SizeInt)}
  function  MulSizeInt(L, R: SizeInt): SizeInt; inline;

var
  BoolRandSeed: DWord = 0;
  procedure RandomizeBoolean;
  function  NextRandomBoolean: Boolean; inline;

  { Bob Jenkins small noncryptographic PRNG
    http://www.burtleburtle.net/bob/rand/smallprng.html }
  procedure BJSetSeed(aSeed: DWord);
  procedure BJSetSeed64(aSeed: QWord);
  procedure BJRandomize;
  procedure BJRandomize64;
  function  BJNextRandom: DWord;
  function  BJNextRandom64: QWord;

  {Splitmix64 PRNG}
var
  SmRandSeed: QWord = 0;
  procedure SmRandomize;
  function  SmNextRandom: QWord; inline;

type
  {$DEFINE USE_TGSET_INITIALIZE}
  { TGSet<T> implements a set of arbitrary(within reason) size based on a bit array;
    T must be of some ordinal type with a cardinality of reasonable magnitude,
    given that the size of the internal bit array is proportional to the cardinality }
  TGSet<T> = record
  private
  const
    LO_VALUE   = Integer(System.Low(T));
    ELEM_COUNT = Succ(Integer(System.High(T)) - LO_VALUE);
    LIMB_COUNT = ELEM_COUNT shr INT_SIZE_LOG + Ord(ELEM_COUNT and INT_SIZE_MASK <> 0);
  type
    TBits = array[0..Pred(LIMB_COUNT)] of SizeUInt;
  var
    FBits: TBits;
    {$IFDEF USE_TGSET_INITIALIZE}
    class operator Initialize(var s: TGSet<T>); inline;
    {$ENDIF USE_TGSET_INITIALIZE}
  public
  type
    TArray = array of T;

    TEnumerator = record
    private
      FBits: PSizeUInt;
      FBitIndex,
      FLimbIndex: Integer;
      FCurrLimb: SizeUInt;
      function  GetCurrent: T; inline;
      function  FindFirst: Boolean;
      procedure Init(aBits: PSizeUInt);
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TDenseEnumerator = record
    private
      FBits: PSizeUInt;
      FCurrIndex: Integer;
      function  GetCurrent: T; inline;
      procedure Init(aBits: PSizeUInt);
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TDenseItems = record
    private
      FBits: PSizeUInt;
    public
      function GetEnumerator: TDenseEnumerator; inline;
    end;

    function  GetEnumerator: TEnumerator; inline;
    function  DenseItems: TDenseItems; inline;
    function  ToArray: TArray;
    function  IsEmpty: Boolean;
    function  Count: Integer;
    procedure Clear; inline;
    procedure Include(aValue: T); inline;
    procedure Exclude(aValue: T); inline;
    procedure IncludeArray(const a: array of T);
    procedure ExcludeArray(const a: array of T);
    function  Contains(aValue: T): Boolean; inline;
    procedure Turn(aValue: T; aOn: Boolean); inline;
    function  Intersecting(const aSet: TGSet<T>): Boolean;
    procedure Intersect(const aSet: TGSet<T>);
    procedure Join(const aSet: TGSet<T>);
    procedure Subtract(const aSet: TGSet<T>);
    procedure SymmetricSubtract(const aSet: TGSet<T>);
    class operator  +(const L, R: TGSet<T>): TGSet<T>;
    class operator  -(const L, R: TGSet<T>): TGSet<T>;
    class operator  *(const L, R: TGSet<T>): TGSet<T>;
    class operator ><(const L, R: TGSet<T>): TGSet<T>;
    class operator  =(const L, R: TGSet<T>): Boolean;
    class operator <=(const L, R: TGSet<T>): Boolean;
    class operator in(aValue: T; const aSet: TGSet<T>): Boolean; inline;
    class operator Implicit(aValue: T): TGSet<T>; inline; overload;
    class operator Explicit(aValue: T): TGSet<T>; inline; overload;
    class operator Implicit(const a: array of T): TGSet<T>; overload;
    class operator Explicit(const a: array of T): TGSet<T>; overload;
  end;

  TGRecRange<T> = record
  private
    FCurrent,
    FLast,
    FStep: T;
    FInLoop: Boolean;
  public
    constructor Create(aFrom, aTo, aStep: T);
    function GetEnumerator: TGRecRange<T>; inline;
    function MoveNext: Boolean; inline;
    property Current: T read FCurrent;
  end;

  TGRecDownRange<T> = record
  private
    FCurrent,
    FLast,
    FStep: T;
    FInLoop: Boolean;
  public
    constructor Create(aFrom, aDownTo, aStep: T);
    function GetEnumerator: TGRecDownRange<T>; inline;
    function MoveNext: Boolean; inline;
    property Current: T read FCurrent;
  end;

{ for numeric types only;
  loop from aFrom to aTo with step aStep;
  if aStep > T(0) then iteration count = Max(0, Int((aTo - aFrom + aStep)/aStep)),
  otherwise 0 }
  function GRange<T>(aFrom, aTo: T; aStep: T{$IF FPC_FULLVERSION>=30301}=T(1){$ENDIF}): TGRecRange<T>; inline;//Mantis #37380
{ for numeric types only;
  loop from aFrom down to aDownTo with step aStep;
  if aStep > T(0) then iteration count = Max(0, Int((aFrom - aDownTo + aStep)/aStep)),
  otherwise 0 }
  function GDownRange<T>(aFrom, aDownTo: T; aStep: T{$IF FPC_FULLVERSION>=30301}=T(1){$ENDIF}): TGRecDownRange<T>; inline;//Mantis #37380

  procedure TurnSetElem<TSet, TElem>(var aSet: TSet; aElem: TElem; aOn: Boolean);{$IF FPC_FULLVERSION>=30202}inline;{$ENDIF}

  function MinOf3(a, b, c: SizeInt): SizeInt; inline;
  function MaxOf3(a, b, c: SizeInt): SizeInt; inline;

type
  TSimMode = (
    smSimple,         // tokenization only
    smTokenSort,      // lexicographic sorting of tokens
    smTokenSet,       // lexicographic sorting of tokens with discarding of non-unique ones(sorted set)
    smTokenSetEx       { tokens are converted to a sorted set,
                         two strings are constructed in the form <intersection><difference>,
                         max ratio of these two strings in certain combinations is taken }
    );

  TSimOption  = (
    soPartial,        // maximum similarity is required when alternately comparing a shorter
                      // string with all parts of the same length of a longer string
    soIgnoreCase);

  TSimOptions = set of TSimOption;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{$PUSH}{$Q-}{$R-}

function BsfSizeUInt(aValue: SizeUInt): ShortInt;
begin
{$IF DEFINED(CPU64)}
  Result := ShortInt(BsfQWord(aValue));
{$ELSEIF DEFINED(CPU32)}
  Result := ShortInt(BsfDWord(aValue));
{$ELSE}
  Result := ShortInt(BsfWord(aValue));
{$ENDIF}
end;

function BsrSizeUInt(aValue: SizeUInt): ShortInt;
begin
{$IF DEFINED(CPU64)}
  Result := ShortInt(BsrQWord(aValue));
{$ELSEIF DEFINED(CPU32)}
  Result := ShortInt(BsrDWord(aValue));
{$ELSE}
  Result := ShortInt(BsrWord(aValue));
{$ENDIF}
end;

function RolSizeInt(aValue: SizeInt; aDist: Byte): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := SizeInt(RolQWord(QWord(aValue), aDist));
{$ELSEIF DEFINED(CPU32)}
  Result := SizeInt(RolDWord(DWord(aValue), aDist));
{$ELSE}
  Result := SizeInt(RolWord(Word(aValue), aDist));
{$ENDIF}
end;

function RorSizeInt(aValue: SizeInt; aDist: Byte): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := SizeInt(RorQWord(QWord(aValue), aDist));
{$ELSEIF DEFINED(CPU32)}
  Result := SizeInt(RorDWord(DWord(aValue), aDist));
{$ELSE}
  Result := SizeInt(RorWord(Word(aValue), aDist));
{$ENDIF}
end;

function NSB(aValue: SizeUInt): SizeInt;
begin
  Result := Succ(BsrSizeUInt(aValue));
end;

function IsTwoPower(aValue: SizeUInt): Boolean;
begin
  if aValue <> 0 then
    exit(aValue and Pred(aValue) = 0);
  Result := False;
end;

function RoundUpTwoPower(aValue: SizeInt): SizeInt;
begin
  Assert(aValue <= MAX_POSITIVE_POW2, Format(SEArgumentTooBigFmt, [{$I %CURRENTROUTINE%}, aValue]));
  if aValue > 1 then
    begin
      if not LGUtils.IsTwoPower(aValue) then
        Result := SizeInt(1) shl LGUtils.NSB(aValue)
      else
        Result := aValue; // round not needed ???
    end
  else
    Result := 2;
end;

function MulSizeInt(L, R: SizeInt): SizeInt;
begin
  if (L = 0) or (R = 0) then
    exit(0);
  Result := L * R;
  if Result div R <> L then
    exit(High(SizeInt));
end;

procedure RandomizeBoolean;
begin
  BoolRandSeed := DWord(GetTickCount64);
end;

function NextRandomBoolean: Boolean;
begin
  BoolRandSeed := BoolRandSeed * DWord(1103515245) + DWord(12345);
  Result := Odd(BoolRandSeed shr 16);
end;

var
  p: DWord = DWord($F2346B68);
  q: DWord = DWord($43E345B9);
  r: DWord = DWord($9BDDD2D5);
  s: DWord = DWord($B78D029B);

  p64: QWord = QWord($C49205791B1F3E34);
  q64: QWord = QWord($84988390DCCAC2DA);
  r64: QWord = QWord($FECAB388259108D9);
  s64: QWord = QWord($7E7F22F098FB479C);

procedure BJSetSeed(aSeed: DWord);
var
  e: DWord;
  I: Integer;
begin
  p := $f1ea5eed;
  q := aSeed;
  r := aSeed;
  s := aSeed;
  for I := 1 to 20 do
    begin
      e := p - RolDWord(q, 23);
      p := q xor RolDWord(r, 16);
      q := r + RolDWord(s, 11);
      r := s + e;
      s := e + p;
    end;
end;

procedure BJSetSeed64(aSeed: QWord);
var
  e: QWord;
  I: Integer;
begin
  p64 := $f1ea5eed;
  q64 := aSeed;
  r64 := aSeed;
  s64 := aSeed;
  for I := 1 to 20 do
    begin
      e := p64 - RolQWord(q64, 7);
      p64 := q64 xor RolQWord(r64, 13);
      q64 := r64 + RolQWord(s64, 37);
      r64 := s64 + e;
      s64 := e + p64;
    end;
end;

procedure BJRandomize;
begin
  BJSetSeed(GetTickCount64);
end;

procedure BJRandomize64;
begin
  BJSetSeed64(GetTickCount64);
end;

function BJNextRandom: DWord;
var
  e: DWord;
begin
  e := p - RolDWord(q, 23);
  p := q xor RolDWord(r, 16);
  q := r + RolDWord(s, 11);
  r := s + e;
  s := e + p;
  Result := s;
end;

function BJNextRandom64: QWord;
var
  e: QWord;
begin
  e := p64 - RolQWord(q64, 7);
  p64 := q64 xor RolQWord(r64, 13);
  q64 := r64 + RolQWord(s64, 37);
  r64 := s64 + e;
  s64 := e + p64;
  Result := s64;
end;

procedure SmRandomize;
begin
  SmRandSeed := GetTickCount64;
end;

function SmNextRandom: QWord;
begin
  Result := SmRandSeed + QWord($9e3779b97f4a7c15);
  SmRandSeed := Result;
  Result := (Result xor (Result shr 30)) * QWord($bf58476d1ce4e5b9);
  Result := (Result xor (Result shr 27)) * QWord($94d049bb133111eb);
  Result := Result xor (Result shr 31);
end;

{$POP}

{ TGOptional }

function TGOptional<T>.GetValue: T;
begin
  if not Assigned then
    raise ELGOptional.Create(SEOptionalValueEmpty);
  Result := FValue;
end;

class constructor TGOptional<T>.InitTypeInfo;
begin
  CFTypeKind := System.GetTypeKind(T);
  CFNilable := CFTypeKind in NilableKinds;
end;

class function TGOptional<T>.IsNil(const aValue): Boolean;
begin
  case CFTypeKind of
    System.tkMethod:       exit(Pointer(aValue) = nil);
    System.tkInterface:    exit(Pointer(aValue) = nil);
    System.tkClass:        exit(TObject(aValue) = nil);
    System.tkInterfaceRaw: exit(Pointer(aValue) = nil);
    System.tkProcVar:      exit(Pointer(aValue) = nil);
    System.tkClassRef:     exit(TClass(aValue)  = nil);
    System.tkPointer:      exit(Pointer(aValue) = nil);
  else //todo: what about Variants ?
  end;
  Result := False;
end;

class operator TGOptional<T>.Initialize(var o: TGOptional<T>);
begin
  o.FAssigned := False;
end;

class operator TGOptional<T>.Implicit(const aValue: T): TGOptional<T>;
begin
  Result.Assign(aValue);
end;

class operator TGOptional<T>.Implicit(const o: TGOptional<T>): T;
begin
  Result := o.Value;
end;

class operator TGOptional<T>.Explicit(const o: TGOptional<T>): T;
begin
  Result := o.Value;
end;

procedure TGOptional<T>.Assign(const aValue: T);
begin
  if CFNilable and IsNil((@aValue)^) then
    exit;
  FValue := aValue;
  FAssigned := True;
end;

function TGOptional<T>.OrElse(const aValue: T): T;
begin
  if Assigned then
    Result := FValue
  else
    Result := aValue;
end;

function TGOptional<T>.OrElseRaise(e: ExceptClass; const aMsg: string): T;
begin
  if not Assigned then
    raise e.Create(aMsg);
  Result := FValue;
end;

{ TGAutoRef<T> }

function TGAutoRef<T>.GetInstance: T;
begin
  if not Assigned(FInstance) then
    begin
      FInstance := T.Create;
      FOwnsInstance := Assigned(FInstance);
    end;
  Result := FInstance;
end;

procedure TGAutoRef<T>.SetInstance(aValue: T);
begin
  if aValue <> FInstance then
    begin
      if OwnsInstance then
        FInstance.Free;
      FInstance := aValue;
      FOwnsInstance := Assigned(FInstance);
    end;
end;

function TGAutoRef<T>.Release: T;
begin
  Result := FInstance;
  FInstance := Default(T);
  FOwnsInstance := False;
end;

class operator TGAutoRef<T>.Initialize(var a: TGAutoRef<T>);
begin
  a.FInstance := Default(T);
  a.FOwnsInstance := False;
end;

class operator TGAutoRef<T>.Finalize(var a: TGAutoRef<T>);
begin
  if a.OwnsInstance then
    a.FInstance.Free;
end;

class operator TGAutoRef<T>.Copy(constref aSrc: TGAutoRef<T>; var aDst: TGAutoRef<T>);
begin
  if @aSrc <> @aDst then
    raise EInvalidOpException.Create(SECopyInadmissible);
end;

class operator TGAutoRef<T>.AddRef(var a: TGAutoRef<T>);
begin
  a.FOwnsInstance := False;
end;

class operator TGAutoRef<T>.Implicit(var a: TGAutoRef<T>): T;
begin
  Result := a.Instance;
end;

class operator TGAutoRef<T>.Explicit(var a: TGAutoRef<T>): T;
begin
  Result := a.Instance;
end;

function TGAutoRef<T>.HasInstance: Boolean;
begin
  Result := Assigned(FInstance);
end;

procedure TGAutoRef<T>.Clear;
begin
  if OwnsInstance then
    FInstance.Free;
  FInstance := Default(T);
  FOwnsInstance := False;
end;

function TGAutoRef<T>.ReleaseInstance: T;
begin
  if not OwnsInstance then
    exit(Default(T));
  Result := Release;
end;

procedure TGAutoRef<T>.OwnMove(var aRef: TGAutoRef<T>);
begin
  if not Assigned(FInstance) then
    exit;
  if OwnsInstance then
    aRef.Instance := Release
  else
    raise EInvalidOpException.Create(SEOwnRequired);
end;

procedure TGUniqRef<T>.SetInstance(aValue: T);
begin
  if aValue <> FInstance then
    begin
      if OwnsInstance then
        FInstance.Free;
      FInstance := aValue;
      FOwnsInstance := Assigned(FInstance);
    end;
end;

function TGUniqRef<T>.Release: T;
begin
  Result := FInstance;
  FInstance := Default(T);
  FOwnsInstance := False;
end;

class operator TGUniqRef<T>.Initialize(var u: TGUniqRef<T>);
begin
  u.FInstance := Default(T);
  u.FOwnsInstance := False;
end;

class operator TGUniqRef<T>.Finalize(var u: TGUniqRef<T>);
begin
  if u.OwnsInstance then
    u.FInstance.Free;
end;

class operator TGUniqRef<T>.Copy(constref aSrc: TGUniqRef<T>; var aDst: TGUniqRef<T>);
begin
  if @aSrc <> @aDst then
    raise EInvalidOpException.Create(SECopyInadmissible);
end;

class operator TGUniqRef<T>.AddRef(var u: TGUniqRef<T>);
begin
  u.FOwnsInstance := False;
end;

class operator TGUniqRef<T>.Implicit(var u: TGUniqRef<T>): T;
begin
  Result := u.Instance;
end;

class operator TGUniqRef<T>.Explicit(var u: TGUniqRef<T>): T;
begin
  Result := u.Instance;
end;

function TGUniqRef<T>.HasInstance: Boolean;
begin
  Result := Assigned(FInstance);
end;

procedure TGUniqRef<T>.Clear;
begin
  if OwnsInstance then
    FInstance.Free;
  FInstance := Default(T);
  FOwnsInstance := False;
end;

function TGUniqRef<T>.ReleaseInstance: T;
begin
  if not OwnsInstance then
    exit(Default(T));
  Result := Release;
end;

procedure TGUniqRef<T>.OwnMove(var aRef: TGUniqRef<T>);
begin
  if not Assigned(FInstance) then
    exit;
  if OwnsInstance then
    aRef.Instance := Release
  else
    raise EInvalidOpException.Create(SEOwnRequired);
end;

{ TGSharedRefA<T> }

procedure TGSharedAutoRef<T>.InitInstance(aValue: T);
begin
  FInstance := aValue;
  if Assigned(aValue) then
    begin
      System.New(FRefCount);
      FRefCount^ := 1;
    end;
end;

function TGSharedAutoRef<T>.GetInstance: T;
begin
  if FRefCount = nil then
    InitInstance(T.Create);
  Result := FInstance;
end;

function TGSharedAutoRef<T>.GetRefCount: Integer;
begin
  if FRefCount <> nil then
    Result := FRefCount^
  else
    Result := 0;
end;

procedure TGSharedAutoRef<T>.SetInstance(aValue: T);
begin
  if aValue <> FInstance then
    begin
      Release;
      InitInstance(aValue);
    end;
end;

class operator TGSharedAutoRef<T>.Initialize(var s: TGSharedAutoRef<T>);
begin
  s.FRefCount := nil;
  s.FInstance := Default(T);
end;

class operator TGSharedAutoRef<T>.Finalize(var s: TGSharedAutoRef<T>);
begin
  s.Release;
end;

class operator TGSharedAutoRef<T>.Copy(constref aSrc: TGSharedAutoRef<T>; var aDst: TGSharedAutoRef<T>);
begin
  if @aSrc <> @aDst then
    begin
      aDst.Release;
      if aSrc.FRefCount <> nil then
        begin
          InterLockedIncrement(aSrc.FRefCount^);
          aDst.FRefCount := aSrc.FRefCount;
          aDst.FInstance := aSrc.Instance;
        end;
    end;
end;

class operator TGSharedAutoRef<T>.AddRef(var s: TGSharedAutoRef<T>);
begin
  if s.FRefCount <> nil then
    InterLockedIncrement(s.FRefCount^);
end;

class operator TGSharedAutoRef<T>.Implicit(var s: TGSharedAutoRef<T>): T;
begin
  Result := s.Instance;
end;

class operator TGSharedAutoRef<T>.Explicit(var s: TGSharedAutoRef<T>): T;
begin
  Result := s.Instance;
end;

function TGSharedAutoRef<T>.HasInstance: Boolean;
begin
  Result := FRefCount <> nil;
end;

procedure TGSharedAutoRef<T>.Release;
begin
  if FRefCount <> nil then
    begin
      if InterlockedDecrement(FRefCount^) = 0 then
        begin
          System.Dispose(FRefCount);
          FInstance.Free;
        end;
      FRefCount := nil;
    end;
end;

{ TGSharedRef<T> }

procedure TGSharedRef<T>.InitInstance(aValue: T);
begin
  FInstance := aValue;
  if Assigned(aValue) then
    begin
      System.New(FRefCount);
      FRefCount^ := 1;
    end;
end;

function TGSharedRef<T>.GetInstance: T;
begin
  if FRefCount = nil then
    exit(Default(T));
  Result := FInstance;
end;

function TGSharedRef<T>.GetRefCount: Integer;
begin
  if FRefCount <> nil then
    Result := FRefCount^
  else
    Result := 0;
end;

procedure TGSharedRef<T>.SetInstance(aValue: T);
begin
  if aValue <> FInstance then
    begin
      Release;
      InitInstance(aValue);
    end;
end;

class operator TGSharedRef<T>.Initialize(var s: TGSharedRef<T>);
begin
  s.FRefCount := nil;
  s.FInstance := Default(T);
end;

class operator TGSharedRef<T>.Finalize(var s: TGSharedRef<T>);
begin
  s.Release;
end;

class operator TGSharedRef<T>.Copy(constref aSrc: TGSharedRef<T>; var aDst: TGSharedRef<T>);
begin
  if @aSrc <> @aDst then
    begin
      aDst.Release;
      if aSrc.FRefCount <> nil then
        begin
          InterLockedIncrement(aSrc.FRefCount^);
          aDst.FRefCount := aSrc.FRefCount;
          aDst.FInstance := aSrc.Instance;
        end;
    end;
end;

class operator TGSharedRef<T>.AddRef(var s: TGSharedRef<T>);
begin
  if s.FRefCount <> nil then
    InterLockedIncrement(s.FRefCount^);
end;

class operator TGSharedRef<T>.Implicit(var s: TGSharedRef<T>): T;
begin
  Result := s.Instance;
end;

class operator TGSharedRef<T>.Explicit(var s: TGSharedRef<T>): T;
begin
  Result := s.Instance;
end;

function TGSharedRef<T>.HasInstance: Boolean;
begin
  Result := FRefCount <> nil;
end;

procedure TGSharedRef<T>.Release;
begin
  if FRefCount <> nil then
    begin
      if InterlockedDecrement(FRefCount^) = 0 then
        begin
          System.Dispose(FRefCount);
          FInstance.Free;
        end;
      FRefCount := nil;
    end;
end;

{ TGUniqPtr }

function TGUniqPtr<T>.GetAllocated: Boolean;
begin
  Result := FPtr <> nil;
end;

function TGUniqPtr<T>.GetPtr: PValue;
begin
  if FPtr = nil then
    begin
      System.New(FPtr);
      FillChar(FPtr^, SizeOf(T), 0);
      FOwnsPtr := True;
    end;
  Result := FPtr;
end;

procedure TGUniqPtr<T>.FreePtr;
begin
  if OwnsPtr then
    begin
      if IsManagedType(T) then
        FPtr^ := Default(T);
      System.Dispose(FPtr);
    end;
end;

function TGUniqPtr<T>.GetValue: T;
begin
  Result := Ptr^;
end;

procedure TGUniqPtr<T>.SetValue(const aValue: T);
begin
  Ptr^ := aValue;
end;

class operator TGUniqPtr<T>.Initialize(var u: TGUniqPtr<T>);
begin
  u.FPtr := nil;
  u.FOwnsPtr := False;
end;

class operator TGUniqPtr<T>.Finalize(var u: TGUniqPtr<T>);
begin
  u.Clear;
end;

class operator TGUniqPtr<T>.Copy(constref aSrc: TGUniqPtr<T>; var aDst: TGUniqPtr<T>);
begin
  if @aSrc <> @aDst then
    raise EInvalidOpException.Create(SECopyInadmissible);
end;

class operator TGUniqPtr<T>.AddRef(var u: TGUniqPtr<T>);
begin
  u.FOwnsPtr := False;
end;

class operator TGUniqPtr<T>.Implicit(var u: TGUniqPtr<T>): T;
begin
  Result := u.Ptr^;
end;

class operator TGUniqPtr<T>.Explicit(var u: TGUniqPtr<T>): T;
begin
  Result := u.Ptr^;
end;

procedure TGUniqPtr<T>.Clear;
begin
  FreePtr;
  FPtr := nil;
  FOwnsPtr := False;
end;

procedure TGUniqPtr<T>.OwnMove(var aPtr: TGUniqPtr<T>);
begin
  if FPtr = nil then
    exit;
  if OwnsPtr then
    begin
      aPtr.FreePtr;
      aPtr.FPtr := FPtr;
      aPtr.FOwnsPtr := True;
      FPtr := nil;
      FOwnsPtr := False;
    end
  else
    raise EInvalidOpException.Create(SEOwnRequired);
end;

{ TGCowPtr }

function TGCowPtr<T>.NewInstance: PInstance;
begin
  System.New(FInstance);
  FInstance^.RefCount := 1;
  FillChar(FInstance^.Value, SizeOf(T), 0);
  Result := FInstance;
end;

procedure TGCowPtr<T>.ReleaseInstance;
begin
  if InterlockedDecrement(FInstance^.RefCount) = 0 then
    begin
      if IsManagedType(T) then
        FInstance^.Value := Default(T);
      System.Dispose(FInstance);
    end;
  FInstance := nil;
end;

function TGCowPtr<T>.GetAllocated: Boolean;
begin
  Result := FInstance <> nil;
end;

function TGCowPtr<T>.GetRefCount: Integer;
begin
  if FInstance <> nil then
    exit(FInstance^.RefCount);
  Result := 0;
end;

function TGCowPtr<T>.GetPtr: PValue;
begin
  if FInstance = nil then
    NewInstance;
  Result := @FInstance^.Value;
end;

function TGCowPtr<T>.GetUniqPtr: PValue;
begin
  Unique;
  Result := GetPtr;
end;

function TGCowPtr<T>.GetValue: T;
begin
  Result := GetPtr^;
end;

procedure TGCowPtr<T>.SetValue(const aValue: T);
begin
  if (FInstance <> nil) and (FInstance^.RefCount > 1) then
    ReleaseInstance;
  GetPtr^ := aValue;
end;

class operator TGCowPtr<T>.Initialize(var cp: TGCowPtr<T>);
begin
  cp.FInstance := nil;
end;

class operator TGCowPtr<T>.Finalize(var cp: TGCowPtr<T>);
begin
  cp.Release;
end;

class operator TGCowPtr<T>.Copy(constref aSrc: TGCowPtr<T>; var aDst: TGCowPtr<T>);
begin
  if @aSrc <> @aDst then
    begin
      aDst.Release;
      if aSrc.FInstance <> nil then
        begin
          aDst.FInstance := aSrc.FInstance;
          InterLockedIncrement(aSrc.FInstance^.RefCount);
        end;
    end;
end;

class operator TGCowPtr<T>.AddRef(var cp: TGCowPtr<T>);
begin
  if cp.FInstance <> nil then
    InterLockedIncrement(cp.FInstance^.RefCount);
end;

class operator TGCowPtr<T>.Implicit(var cp: TGCowPtr<T>): T;
begin
  Result := cp.GetPtr^;
end;

class operator TGCowPtr<T>.Explicit(var cp: TGCowPtr<T>): T;
begin
  Result := cp.GetPtr^;
end;

procedure TGCowPtr<T>.Release;
begin
  if FInstance <> nil then
    ReleaseInstance;
end;

procedure TGCowPtr<T>.Unique;
var
  Old: PInstance;
begin
  if (FInstance <> nil) and (FInstance^.RefCount > 1) then
    begin
      Old := FInstance;
      NewInstance^.Value := Old^.Value;
      InterlockedDecrement(Old^.RefCount);
    end;
end;

{ TGCowDynArray<T>.TEnumerator }

function TGCowDynArray<T>.TEnumerator.GetCurrent: T;
begin
  Result := FCurrent^;
end;

function TGCowDynArray<T>.TEnumerator.MoveNext: Boolean;
begin
  if FCurrent < FLast then
    begin
      Inc(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGCowDynArray<T>.TReverseEnumerator }

function TGCowDynArray<T>.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrent^;
end;

function TGCowDynArray<T>.TReverseEnumerator.MoveNext: Boolean;
begin
  if FCurrent > FFirst then
    begin
      Dec(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGCowDynArray<T>.TReverse }

function TGCowDynArray<T>.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result := FArray^.GetReverseEnumerator;
end;

{ TGCowDynArray }

function TGCowDynArray<T>.NewInstance: PInstance;
begin
  System.New(Result);
  Result^.FItems := nil;
  Result^.FLength := 0;
  Result^.FRefCount := 1;
end;

procedure TGCowDynArray<T>.UniqInstance;
var
  OldInstance: PInstance;
begin
  OldInstance := FInstance;
  FInstance := NewInstance;
  FInstance^.FLength := OldInstance^.FLength;
  if FInstance^.FLength > 0 then
    begin
      FInstance^.FItems := System.GetMem(FInstance^.FLength * SizeOf(T));
      if IsManagedType(T) then
        begin
          System.FillChar(FInstance^.FItems^, FInstance^.FLength * SizeOf(T), 0);
          CopyItems(OldInstance^.FItems, FInstance^.FItems, FInstance^.FLength);
        end
      else
        System.Move(OldInstance^.FItems^, FInstance^.FItems^, FInstance^.FLength * SizeOf(T));
    end;
  InterlockedDecrement(OldInstance^.FRefCount);
end;

procedure TGCowDynArray<T>.ReallocUniq(aNewLen: SizeInt);
var
  OldInstance: PInstance;
begin
  OldInstance := FInstance;
  FInstance := NewInstance;
  FInstance^.FLength := aNewLen;
  if FInstance^.FLength > 0 then
    begin
      FInstance^.FItems := System.GetMem(FInstance^.FLength * SizeOf(T));
      if IsManagedType(T) then
        System.FillChar(FInstance^.FItems^, FInstance^.FLength * SizeOf(T), 0);
      CopyItems(OldInstance^.FItems, FInstance^.FItems, Math.Min(FInstance^.FLength, OldInstance^.FLength));
    end;
  InterlockedDecrement(OldInstance^.FRefCount);
end;

procedure TGCowDynArray<T>.Realloc(aNewLen: SizeInt);
begin
  if IsManagedType(T) then
    ReallocManaged(aNewLen)
  else
    FInstance^.FItems := System.ReallocMem(FInstance^.FItems, aNewLen * SizeOf(T));
  FInstance^.FLength := aNewLen;
end;

procedure TGCowDynArray<T>.ReallocManaged(aNewLen: SizeInt);
var
  Tmp: PItem;
begin
  Tmp := System.GetMem(aNewLen * SizeOf(T));
  with FInstance^ do
    begin
      if aNewLen > FLength then
        begin
          if FLength <> 0 then
            begin
              System.Move(FItems^, Tmp^, FLength * SizeOf(T));
              System.FillChar(FItems^, FLength * SizeOf(T), 0);
            end;
          System.FillChar(Tmp[FLength], (aNewLen - FLength) * SizeOf(T), 0);
        end
      else  //aNewLen < aOldLen
        begin
          System.Move(FItems^, Tmp^, aNewLen * SizeOf(T));
          System.FillChar(FItems^, aNewLen * SizeOf(T), 0);
          FillItems(FItems + aNewLen, FLength - aNewLen, Default(T));
        end;
      System.FreeMem(FItems);
      FItems := Tmp;
    end;
end;

function TGCowDynArray<T>.GetLength: SizeInt;
begin
  if FInstance <> nil then
    exit(FInstance^.FLength);
  Result := 0;
end;

function TGCowDynArray<T>.GetRefCount: Integer;
begin
  if FInstance <> nil then
    exit(FInstance^.FRefCount);
  Result := 0;
end;

function TGCowDynArray<T>.GetItem(aIndex: SizeInt): T;
begin
{$IFOPT R+}
  if (FInstance <> nil) and (SizeUInt(aIndex) < SizeUInt(FInstance^.FLength)) then
    Result := FInstance^.FItems[aIndex]
  else
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
{$ELSE}
  Result := FInstance^.FItems[aIndex];
{$ENDIF}
end;

function TGCowDynArray<T>.GetPtr: PItem;
begin
  if FInstance = nil then
    FInstance := NewInstance;
  Result := FInstance^.FItems;
end;

function TGCowDynArray<T>.GetUniqPtr: PItem;
begin
  if FInstance = nil then
    FInstance := NewInstance
  else
    if FInstance^.FRefCount > 1 then
      UniqInstance;
  Result := FInstance^.FItems;
end;

procedure TGCowDynArray<T>.SetLen(aValue: SizeInt);
begin
  if aValue <> Length then
    begin
      if aValue = 0 then
        begin
          Release;
          exit;
        end;
      if aValue > 0 then
        begin
          if FInstance = nil then
            FInstance := NewInstance;
          if FInstance^.FRefCount > 1 then
            ReallocUniq(aValue)
          else
            Realloc(aValue);
        end
      else
        raise EInvalidOpException.Create(SECantAcceptNegLen);
    end;
end;

procedure TGCowDynArray<T>.SetItem(aIndex: SizeInt; const aValue: T);
begin
{$IFOPT R+}
  if (FInstance <> nil) and (SizeUInt(aIndex) < SizeUInt(FInstance^.FLength)) then
    begin
      if FInstance^.FRefCount > 1 then
        UniqInstance;
      FInstance^.FItems[aIndex] := aValue;
    end
  else
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
{$ELSE}
  if FInstance^.FRefCount > 1 then
    UniqInstance;
  FInstance^.FItems[aIndex] := aValue;
{$ENDIF}
end;

function TGCowDynArray<T>.GetHigh: SizeInt;
begin
  if FInstance <> nil then
    exit(Pred(FInstance^.FLength));
  Result := NULL_INDEX;
end;

class procedure TGCowDynArray<T>.FillItems(aFrom: PItem; aCount: SizeInt; const aValue: T);
begin
  while aCount >= 4 do
    begin
      aFrom[0] := aValue;
      aFrom[1] := aValue;
      aFrom[2] := aValue;
      aFrom[3] := aValue;
      aFrom += 4;
      aCount -= 4;
    end;
  case aCount of
    1: aFrom[0] := aValue;
    2:
      begin
        aFrom[0] := aValue;
        aFrom[1] := aValue;
      end;
    3:
      begin
        aFrom[0] := aValue;
        aFrom[1] := aValue;
        aFrom[2] := aValue;
      end;
  else
  end;
end;

class procedure TGCowDynArray<T>.CopyItems(aSrc, aDst: PItem; aCount: SizeInt);
var
  I: SizeInt;
begin
  I := 0;
  while I <= aCount - 4 do
    begin
      aDst[I  ] := aSrc[I  ];
      aDst[I+1] := aSrc[I+1];
      aDst[I+2] := aSrc[I+2];
      aDst[I+3] := aSrc[I+3];
      I += 4;
    end;
  case aCount - I of
    1: aDst[I] := aSrc[I];
    2:
      begin
        aDst[I  ] := aSrc[I  ];
        aDst[I+1] := aSrc[I+1];
      end;
    3:
      begin
        aDst[I  ] := aSrc[I  ];
        aDst[I+1] := aSrc[I+1];
        aDst[I+2] := aSrc[I+2];
      end;
  else
  end;
end;

class operator TGCowDynArray<T>.Initialize(var a: TGCowDynArray<T>);
begin
  a.FInstance := nil;
end;

class operator TGCowDynArray<T>.Finalize(var a: TGCowDynArray<T>);
begin
  a.Release;
end;

class operator TGCowDynArray<T>.Copy(constref aSrc: TGCowDynArray<T>; var aDst: TGCowDynArray<T>);
begin
  if @aSrc <> @aDst then
    begin
      aDst.Release;
      if aSrc.FInstance <> nil then
        begin
          InterLockedIncrement(aSrc.FInstance^.FRefCount);
          aDst.FInstance := aSrc.FInstance;
        end;
    end;
end;

class operator TGCowDynArray<T>.AddRef(var a: TGCowDynArray<T>);
begin
  if a.FInstance <> nil then
    InterLockedIncrement(a.FInstance^.FRefCount);
end;

function TGCowDynArray<T>.GetReverseEnumerator: TReverseEnumerator;
begin
  if (FInstance <> nil) and (FInstance^.FItems <> nil) then
    begin
      Result.FCurrent := FInstance^.FItems + FInstance^.FLength;
      Result.FFirst := FInstance^.FItems;
      exit;
    end;
  Result.FCurrent := nil;
  Result.FFirst := nil;
end;

function TGCowDynArray<T>.GetEnumerator: TEnumerator;
begin
  if (FInstance <> nil) and (FInstance^.FItems <> nil) then
    begin
      Result.FCurrent := FInstance^.FItems - 1;
      Result.FLast := FInstance^.FItems + FInstance^.FLength - 1;
      exit;
    end;
  Result.FCurrent := nil;
  Result.FLast := nil;
end;

function TGCowDynArray<T>.Reverse: TReverse;
begin
  Result.FArray := @Self;
end;

function TGCowDynArray<T>.IsEmpty: Boolean;
begin
  if FInstance <> nil then
    exit(FInstance^.FItems = nil);
  Result := True;
end;

function TGCowDynArray<T>.NonEmpty: Boolean;
begin
  if FInstance <> nil then
    exit(FInstance^.FItems <> nil);
  Result := False;
end;

procedure TGCowDynArray<T>.Release;
begin
  if FInstance = nil then exit;
  if InterlockedDecrement(FInstance^.FRefCount) = 0 then
    begin
      if FInstance^.FItems <> nil then
        begin
          if IsManagedType(T) then
            FillItems(FInstance^.FItems, FInstance^.FLength, Default(T));
          System.FreeMem(FInstance^.FItems);
        end;
      System.Dispose(FInstance);
    end;
  FInstance := nil;
end;

procedure TGCowDynArray<T>.Unique;
begin
  if (FInstance <> nil) and (FInstance^.FRefCount > 1) then
    UniqInstance;
end;

procedure TGCowDynArray<T>.Fill(aCount: SizeInt; const aValue: T);
begin
  Release;
  if aCount < 1 then
    exit;
  Length := aCount;
  FillItems(FInstance^.FItems, aCount, aValue);
end;

function TGCowDynArray<T>.CreateCopy(aFromIndex, aCount: SizeInt): TGCowDynArray<T>;
begin
  if aFromIndex < 0 then
    aFromIndex := 0;
  Result{%H-}.Release;
  if (aFromIndex >= Length) or (aCount < 1) then
    exit;
  aCount := Math.Min(aCount, Length - aFromIndex);
  Result.Length := aCount;
  if IsManagedType(T) then
    CopyItems(FInstance^.FItems + aFromIndex, Result.FInstance^.FItems, aCount)
  else
    System.Move((FInstance^.FItems + aFromIndex)^, Result.FInstance^.FItems^, aCount * SizeOf(T));
end;

{ TGDynArray<T>.TEnumerator }

function TGDynArray<T>.TEnumerator.GetCurrent: T;
begin
  Result := FCurrent^;
end;

function TGDynArray<T>.TEnumerator.MoveNext: Boolean;
begin
  if FCurrent < FLast then
    begin
      Inc(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGDynArray<T>.TReverseEnumerator }

function TGDynArray<T>.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrent^;
end;

function TGDynArray<T>.TReverseEnumerator.MoveNext: Boolean;
begin
  if FCurrent > FFirst then
    begin
      Dec(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGDynArray<T>.TReverse }

function TGDynArray<T>.TReverse.GetEnumerator: TReverseEnumerator;
begin
  with FArray^ do
    if Length > 0 then
      begin
        Result.FFirst := FItems;
        Result.FCurrent := FItems + Length;
      end
    else
      begin
        Result.FCurrent := nil;
        Result.FFirst := nil;
      end;
end;

{ TGDynArray<T>.TMutableEnumerator }

function TGDynArray<T>.TMutableEnumerator.MoveNext: Boolean;
begin
  if FCurrent < FLast then
    begin
      Inc(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGDynArray<T>.TMutables }

function TGDynArray<T>.TMutables.GetEnumerator: TMutableEnumerator;
begin
  with FArray^ do
    if Length > 0 then
      begin
        Result.FCurrent := FItems - 1;
        Result.FLast := FItems + Length - 1;
      end
    else
      begin
        Result.FCurrent := nil;
        Result.FLast := nil;
      end;
end;

{ TGDynArray }

procedure TGDynArray<T>.FillItems(aFrom: PItem; aCount: SizeInt; constref aValue: T);
begin
  while aCount >= 4 do
    begin
      aFrom[0] := aValue;
      aFrom[1] := aValue;
      aFrom[2] := aValue;
      aFrom[3] := aValue;
      aFrom += 4;
      aCount -= 4;
    end;
  case aCount of
    1: aFrom[0] := aValue;
    2:
      begin
        aFrom[0] := aValue;
        aFrom[1] := aValue;
      end;
    3:
      begin
        aFrom[0] := aValue;
        aFrom[1] := aValue;
        aFrom[2] := aValue;
      end;
  else
  end;
end;

procedure TGDynArray<T>.ReallocManaged(aNewLen: SizeInt);
var
  Tmp: PItem;
  OldLen: SizeInt;
begin
  Tmp := System.GetMem(aNewLen * SizeOf(T));
  OldLen := Length;
  if aNewLen > OldLen then
    begin
      System.Move(FItems^, Tmp^, OldLen * SizeOf(T));
      System.FillChar(FItems^, OldLen * SizeOf(T), 0);
      System.FillChar(Tmp[OldLen], (aNewLen - OldLen) * SizeOf(T), 0);
    end
  else  //aNewLen < OldLen
    begin
      System.Move(FItems^, Tmp^, aNewLen * SizeOf(T));
      System.FillChar(FItems^, aNewLen * SizeOf(T), 0);
      FillItems(FItems + aNewLen, OldLen - aNewLen, Default(T));
    end;
  System.FreeMem(FItems);
  FItems := Tmp;
end;

procedure TGDynArray<T>.SetLen(aValue: SizeInt);
begin
  if aValue <> Length then
    begin
      if aValue = 0 then
        begin
          Clear;
          exit;
        end;
      if aValue > 0 then
        begin
          if FItems = nil then
            begin
              FItems := System.GetMem(aValue * SizeOf(T));
              if IsManagedType(T) then
                System.FillChar(FItems^, aValue * SizeOf(T), 0);
            end
          else
            if IsManagedType(T) then
              ReallocManaged(aValue)
            else
              FItems := System.ReallocMem(FItems, aValue * SizeOf(T));
          FLength := aValue;
        end
      else
        raise EInvalidOpException.Create(SECantAcceptNegLen);
    end;
end;

function TGDynArray<T>.GetItem(aIndex: SizeInt): T;
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(Length) then
    Result := FItems[aIndex]
  else
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
{$ELSE}
   Result := FItems[aIndex];
{$ENDIF}
end;

procedure TGDynArray<T>.SetItem(aIndex: SizeInt; const aValue: T);
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(Length) then
    FItems[aIndex] := aValue
  else
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
{$ELSE}
  FItems[aIndex] := aValue;
{$ENDIF}
end;

function TGDynArray<T>.GetHigh: SizeInt;
begin
  Result := Pred(Length);
end;

class procedure TGDynArray<T>.CopyItems(aSrc, aDst: PItem; aCount: SizeInt);
var
  I: SizeInt;
begin
  I := 0;
  while I <= aCount - 4 do
    begin
      aDst[I  ] := aSrc[I  ];
      aDst[I+1] := aSrc[I+1];
      aDst[I+2] := aSrc[I+2];
      aDst[I+3] := aSrc[I+3];
      I += 4;
    end;
  case aCount - I of
    1: aDst[I] := aSrc[I];
    2:
      begin
        aDst[I  ] := aSrc[I  ];
        aDst[I+1] := aSrc[I+1];
      end;
    3:
      begin
        aDst[I  ] := aSrc[I  ];
        aDst[I+1] := aSrc[I+1];
        aDst[I+2] := aSrc[I+2];
      end;
  else
  end;
end;

class operator TGDynArray<T>.Initialize(var a: TGDynArray<T>);
begin
  a.FItems := nil;
  a.FLength := 0;
end;

class operator TGDynArray<T>.Finalize(var a: TGDynArray<T>);
begin
  a.Clear;
end;

class operator TGDynArray<T>.Copy(constref aSrc: TGDynArray<T>; var aDst: TGDynArray<T>);
begin
  if @aSrc <> @aDst then
    begin
      aDst.Clear;
      if aSrc.Length <> 0 then
        begin
          aDst.Length := aSrc.Length;
          if IsManagedType(T) then
            CopyItems(aSrc.FItems, aDst.FItems, aSrc.Length)
          else
            System.Move(aSrc.FItems^, aDst.FItems^, aSrc.Length * SizeOf(T));
        end;
    end;
end;

class operator TGDynArray<T>.AddRef(var a: TGDynArray<T>);
var
  OldItems: PItem;
begin
  if a.Length <> 0 then
    begin
      OldItems := a.FItems;
      a.FItems := System.GetMem(a.Length * SizeOf(T));
      if IsManagedType(T) then
        begin
          System.FillChar(a.FItems^, a.Length * SizeOf(T), 0);
          CopyItems(OldItems, a.FItems, a.Length)
        end
      else
        System.Move(OldItems^, a.FItems^, a.Length * SizeOf(T));
    end;
end;

function TGDynArray<T>.GetEnumerator: TEnumerator;
begin
  if Length > 0 then
    begin
      Result.FCurrent := FItems - 1;
      Result.FLast := FItems + Length - 1;
    end
  else
    begin
      Result.FCurrent := nil;
      Result.FLast := nil;
    end;
end;

function TGDynArray<T>.Reverse: TReverse;
begin
  Result.FArray := @Self;
end;

function TGDynArray<T>.Mutables: TMutables;
begin
  Result.FArray := @Self;
end;

function TGDynArray<T>.IsEmpty: Boolean;
begin
  Result := Length = 0;
end;

function TGDynArray<T>.NonEmpty: Boolean;
begin
  Result := Length <> 0;
end;

procedure TGDynArray<T>.Fill(aCount: SizeInt; constref aValue: T);
begin
  Clear;
  if aCount < 1 then
    exit;
  Length := aCount;
  FillItems(FItems, Length, aValue);
end;

function TGDynArray<T>.CreateCopy(aFromIndex, aCount: SizeInt): TGDynArray<T>;
begin
  if aFromIndex < 0 then
    aFromIndex := 0;
  if (aFromIndex >= Length) or (aCount < 1) then
    begin
      Result.Clear;
      exit;
    end;
  aCount := Math.Min(aCount, Length - aFromIndex);
  Result.Length := aCount;
  if IsManagedType(T) then
    CopyItems(FItems + aFromIndex, Result.FItems, aCount)
  else
    System.Move((FItems + aFromIndex)^, Result.FItems^, aCount * SizeOf(T));
end;

procedure TGDynArray<T>.Clear;
begin
  if Length > 0 then
    begin
      if IsManagedType(T) then
        FillItems(FItems, Length, Default(T));
      FreeMem(FItems);
      FItems := nil;
      FLength := 0;
    end;
end;

{ TGMapEntry }

constructor TGMapEntry<TKey, TValue>.Create(constref aKey: TKey; constref aValue: TValue);
begin
  Key := aKey;
  Value := aValue;
end;

{ TGCell2D }

constructor TGCell2D<TRow, TCol, TValue>.Create(const aRow: TRow; const aCol: TCol; const aValue: TValue);
begin
  Row := aRow;
  Column := aCol;
  Value := aValue;
end;

{ TGNodeManager }

procedure TGNodeManager<TNode>.Put2FreeList(aNode: PNode);
begin
  aNode^.NextLink := Head;
  FHead := aNode;
  Inc(FFreeCount);
end;

class function TGNodeManager<TNode>.CreateNode: PNode;
begin
  System.New(Result);
  System.FillChar(Result^, SizeOf(TNode), 0);
end;

destructor TGNodeManager<TNode>.Destroy;
begin
  ClearFreeList;
  inherited;
end;

function TGNodeManager<TNode>.NewNode: PNode;
begin
  if Head <> nil then
    begin
      Result := Head;
      FHead := Result^.NextLink;
      Result^.NextLink := nil;
      Dec(FFreeCount);
    end
  else
    Result := CreateNode;
end;

procedure TGNodeManager<TNode>.DisposeNode(aNode: PNode);
begin
  System.Dispose(aNode);
end;

procedure TGNodeManager<TNode>.FreeNode(aNode: PNode);
begin
  Put2FreeList(aNode);
end;

procedure TGNodeManager<TNode>.EnsureFreeCount(aCount: SizeInt);
begin
  while aCount > FreeCount do
    Put2FreeList(CreateNode);
end;

procedure TGNodeManager<TNode>.ClearFreeList;
var
  CurrNode, NextNode: PNode;
begin
  CurrNode := Head;
  while CurrNode <> nil do
    begin
      NextNode := CurrNode^.NextLink;
      System.Dispose(CurrNode);
      CurrNode := NextNode;
      Dec(FFreeCount);
    end;
  FHead := nil;
  Assert(FFreeCount = 0, Format('Inconsistent FFreeCount value(%d)', [FFreeCount]));
end;

procedure TGNodeManager<TNode>.Clear;
begin
  ClearFreeList;
end;

{ TGPageNodeManager }

procedure TGPageNodeManager<TNode>.NewPage;
var
  CurrPage: PPage;
  LastNode: PNode;
  I: Integer;
begin
  System.New(CurrPage);
  System.FillChar(CurrPage^, SizeOf(TPage), 0);
  CurrPage^.NextPage := FPageListHead;
  FPageListHead := CurrPage;
  with CurrPage^ do
    begin
      LastNode := FFreeListHead;
      I := 1;
      while I <= NODES_PER_PAGE - 4 do
        begin
          Nodes[I  ].NextLink := LastNode;
          Nodes[I+1].NextLink := @Nodes[I  ];
          Nodes[I+2].NextLink := @Nodes[I+1];
          Nodes[I+3].NextLink := @Nodes[I+2];
          LastNode := @Nodes[I+3];
          I += 4;
        end;
      for I := I to NODES_PER_PAGE do
        begin
          Nodes[I].NextLink := LastNode;
          LastNode := @Nodes[I];
        end;
      FFreeListHead := LastNode;
    end;
  Inc(FPageCount);
  FFreeCount += NODES_PER_PAGE;
end;

destructor TGPageNodeManager<TNode>.Destroy;
begin
  Clear;
  inherited;
end;

function TGPageNodeManager<TNode>.NewNode: PNode;
begin
  if FFreeListHead = nil then
    NewPage;
  Result := FFreeListHead;
  FFreeListHead := Result^.NextLink;
  Result^.NextLink := nil;
  Dec(FFreeCount);
end;

procedure TGPageNodeManager<TNode>.DisposeNode(aNode: PNode);
begin
  aNode^.NextLink := FFreeListHead;
  FFreeListHead := aNode;
  Inc(FFreeCount);
end;

procedure TGPageNodeManager<TNode>.FreeNode(aNode: PNode);
begin
  aNode^.NextLink := FFreeListHead;
  FFreeListHead := aNode;
  Inc(FFreeCount);
end;

procedure TGPageNodeManager<TNode>.EnsureFreeCount(aCount: SizeInt);
begin
  while FreeCount < aCount do
    NewPage;
end;

procedure TGPageNodeManager<TNode>.ClearFreeList;
begin
  // do nothing
end;

procedure TGPageNodeManager<TNode>.Clear;
var
  CurrPage, NextPage: PPage;
begin
  FFreeListHead := nil;
  CurrPage := FPageListHead;
  while CurrPage <> nil do
    begin
      NextPage := CurrPage^.NextPage;
      System.Dispose(CurrPage);
      CurrPage := NextPage;
      Dec(FPageCount);
    end;
  FPageListHead := nil;
  FFreeCount := 0;
  Assert(FPageCount = 0, Format('Inconsistent FPageCount value(%d)', [FPageCount]));
end;

{ TGJoinableNodeManager }

procedure TGJoinableNodeManager<TNode>.Put2FreeList(aNode: PNode);
begin
  aNode^.NextLink := FHead;
  FHead := aNode;
  Inc(FFreeCount);
  if FTail = nil then
    FTail := aNode;
end;

class function TGJoinableNodeManager<TNode>.CreateNode: PNode;
begin
  System.New(Result);
  System.FillChar(Result^, SizeOf(TNode), 0);
end;

class operator TGJoinableNodeManager<TNode>.Finalize(var nm: TGJoinableNodeManager<TNode>);
begin
  nm.Clear;
end;

function TGJoinableNodeManager<TNode>.NewNode: PNode;
begin
  if FHead <> nil then
    begin
      Result := FHead;
      FHead := Result^.NextLink;
      Result^.NextLink := nil;
      Dec(FFreeCount);
      if FHead = nil then
        FTail := nil;
    end
  else
    Result := CreateNode;
end;

procedure TGJoinableNodeManager<TNode>.DisposeNode(aNode: PNode);
begin
  System.Dispose(aNode);
end;

procedure TGJoinableNodeManager<TNode>.FreeNode(aNode: PNode);
begin
  Put2FreeList(aNode);
end;

procedure TGJoinableNodeManager<TNode>.EnsureFreeCount(aCount: SizeInt);
begin
  while aCount > FreeCount do
    Put2FreeList(CreateNode);
end;

procedure TGJoinableNodeManager<TNode>.ClearFreeList;
var
  CurrNode, NextNode: PNode;
begin
  CurrNode := FHead;
  while CurrNode <> nil do
    begin
      NextNode := CurrNode^.NextLink;
      System.Dispose(CurrNode);
      CurrNode := NextNode;
      Dec(FFreeCount);
    end;
  FHead := nil;
  FTail := nil;
  Assert(FFreeCount = 0, Format('Inconsistent FFreeCount value(%d)', [FFreeCount]));
end;

procedure TGJoinableNodeManager<TNode>.Clear;
begin
  ClearFreeList;
end;

procedure TGJoinableNodeManager<TNode>.Join(var nm: TGJoinableNodeManager<TNode>);
begin
  if nm.FreeCount > 0 then
    begin
      if FreeCount > 0 then
        FTail^.NextLink := nm.FHead
      else
        FHead := nm.FHead;
      FTail := nm.FTail;
      FFreeCount += nm.FreeCount;
      nm.FFreeCount := 0;
      nm.FHead := nil;
      nm.FTail := nil;
    end;
end;

{ TGTuple2 }

constructor TGTuple2<T1, T2>.Create(const v1: T1; const v2: T2);
begin
  F1 := v1;
  F2 := v2;
end;

{ TGTuple3 }

constructor TGTuple3<T1, T2, T3>.Create(const v1: T1; const v2: T2; const v3: T3);
begin
  F1 := v1;
  F2 := v2;
  F3 := v3;
end;

{ TGTuple4 }

constructor TGTuple4<T1, T2, T3, T4>.Create(const v1: T1; const v2: T2; const v3: T3; const v4: T4);
begin
  F1 := v1;
  F2 := v2;
  F3 := v3;
  F4 := v4;
end;

{ TGTuple5 }

constructor TGTuple5<T1, T2, T3, T4, T5>.Create(const v1: T1; const v2: T2; const v3: T3; const v4: T4;
  const v5: T5);
begin
  F1 := v1;
  F2 := v2;
  F3 := v3;
  F4 := v4;
  F5 := v5;
end;

{ TGAddMonoid }

class function TGAddMonoid<T>.GetIdentity: T;
begin
  Result := Default(T);
end;

class function TGAddMonoid<T>.BinOp(const L, R: T): T;
begin
  Result := L + R;
end;

{ TGAddMonoidEx }

class function TGAddMonoidEx<T>.GetZeroConst: T;
begin
  Result := Default(T);
end;

class function TGAddMonoidEx<T>.AddConst(const aValue, aConst: T; aSize: SizeInt): T;
begin
  Result := aValue + aConst * aSize;
end;

class function TGAddMonoidEx<T>.IsZeroConst(const aValue: T): Boolean;
begin
  Result := aValue = Default(T);
end;

{ TGMaxMonoid }

class function TGMaxMonoid<T>.GetIdentity: T;
begin
  Result := T.MinValue;
end;

class function TGMaxMonoid<T>.BinOp(const L, R: T): T;
begin
  if L < R then
    Result := R
  else
    Result := L
end;

{ TGMaxMonoidEx }

class function TGMaxMonoidEx<T>.GetZeroConst: T;
begin
  Result := Default(T);
end;

class function TGMaxMonoidEx<T>.AddConst(const aValue, aConst: T; aSize: SizeInt): T;
begin
  Result := aValue + aConst;
end;

class function TGMaxMonoidEx<T>.IsZeroConst(const aValue: T): Boolean;
begin
  Result := aValue = Default(T);
end;

{ TGMinMonoid }

class function TGMinMonoid<T>.GetIdentity: T;
begin
  Result := T.MaxValue;
end;

class function TGMinMonoid<T>.BinOp(const L, R: T): T;
begin
  if R < L then
    Result := R
  else
    Result := L
end;

{ TGMinMonoidEx }

class function TGMinMonoidEx<T>.GetZeroConst: T;
begin
  Result := Default(T);
end;

class function TGMinMonoidEx<T>.AddConst(const aValue, aConst: T; aSize: SizeInt): T;
begin
  Result := aValue + aConst;
end;

class function TGMinMonoidEx<T>.IsZeroConst(const aValue: T): Boolean;
begin
  Result := aValue = Default(T);
end;

{ TGMaxPos }

class function TGMaxPos<T>.GetIdentity: TGMaxPos<T>;
begin
  Result.Value := T.MinValue;
  Result.Index := NULL_INDEX;
end;

class function TGMaxPos<T>.BinOp(const L, R: TGMaxPos<T>): TGMaxPos<T>;
begin
  if R.Value > L.Value then
    Result := R
  else
    Result := L;
end;

{ TGMinPos }

class function TGMinPos<T>.GetIdentity: TGMinPos<T>;
begin
  Result.Value := T.MaxValue;
  Result.Index := NULL_INDEX;
end;

class function TGMinPos<T>.BinOp(const L, R: TGMinPos<T>): TGMinPos<T>;
begin
  if R.Value < L.Value then
    Result := R
  else
    Result := L;
end;

{ TSpinLock }

class operator TSpinLock.Initialize(var sl: TSpinLock);
begin
  sl.FState := 0;
  Assert(SizeOf(sl.FCacheLinePad) = TSpinLock.CACHE_PAD_SIZE);//to supress hints
end;

procedure TSpinLock.Lock;
begin
  while InterlockedExchange(FState, DWord(1)) <> 0 do
    ThreadSwitch;
end;

procedure TSpinLock.LockTts;
begin
  repeat
    while Boolean(FState) do;
    if InterlockedExchange(FState, DWord(1)) = 0 then
      exit;
  until False;
end;

function TSpinLock.TryLock: Boolean;
begin
  Result := InterlockedExchange(FState, DWord(1)) = 0;
end;

procedure TSpinLock.Unlock;
begin
  InterlockedExchange(FState, DWord(0));
end;

{ TGSet<T>.TEnumerator }

function TGSet<T>.TEnumerator.GetCurrent: T;
begin
  Result := T(FLimbIndex shl INT_SIZE_LOG + FBitIndex + LO_VALUE);
end;

function TGSet<T>.TEnumerator.FindFirst: Boolean;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] <> 0 then
      begin
        FBitIndex := BsfSizeUInt(FBits[I]);
        FLimbIndex := I;
        FCurrLimb := FBits[I] and not(SizeUInt(1) shl FBitIndex);
        exit(True);
      end;
  Result := False;
end;

procedure TGSet<T>.TEnumerator.Init(aBits: PSizeUInt);
begin
  FBits := aBits;
  FLimbIndex := -1;
end;

function TGSet<T>.TEnumerator.MoveNext: Boolean;
begin
  if FLimbIndex <> -1 then
    begin
      Result := False;
      repeat
        if FCurrLimb <> 0 then
          begin
            FBitIndex := BsfSizeUInt(FCurrLimb);
            FCurrLimb := FCurrLimb and not (SizeUInt(1) shl FBitIndex);
            exit(True);
          end
        else
          begin
            if FLimbIndex = Pred(LIMB_COUNT) then
              exit(False);
            Inc(FLimbIndex);
            FCurrLimb := FBits[FLimbIndex];
          end;
      until False;
    end
  else
    Result := FindFirst;
end;

{ TGSet.TDenseEnumerator }

function TGSet<T>.TDenseEnumerator.GetCurrent: T;
begin
  Result := T(FCurrIndex + LO_VALUE);
end;

procedure TGSet<T>.TDenseEnumerator.Init(aBits: PSizeUInt);
begin
  FBits := aBits;
  FCurrIndex := -1;
end;

function TGSet<T>.TDenseEnumerator.MoveNext: Boolean;
begin
  while FCurrIndex < Pred(ELEM_COUNT) do
    begin
      Inc(FCurrIndex);
      if FBits[FCurrIndex shr INT_SIZE_LOG] and (SizeUInt(1)shl(FCurrIndex and INT_SIZE_MASK)) <> 0 then
        exit(True);
    end;
  Result := False;
end;

{ TGSet.TDenseItems }

function TGSet<T>.TDenseItems.GetEnumerator: TDenseEnumerator;
begin
  Result.Init(FBits);
end;

{ TGSet }

{$IFDEF USE_TGSET_INITIALIZE}
class operator TGSet<T>.Initialize(var s: TGSet<T>);
begin
  s.FBits := Default(TBits);
end;
{$ENDIF}

function TGSet<T>.GetEnumerator: TEnumerator;
begin
  Result.Init(@FBits[0]);
end;

function TGSet<T>.DenseItems: TDenseItems;
begin
  Result.FBits := @FBits[0];
end;

function TGSet<T>.ToArray: TArray;
var
  I: Integer = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if System.Length(Result) = I then
          System.SetLength(Result, I + I);
        Result[I] := Current;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

function TGSet<T>.IsEmpty: Boolean;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] <> 0 then
      exit(False);
  Result := True;
end;

function TGSet<T>.Count: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Pred(LIMB_COUNT) do
    Result += Integer(PopCnt(FBits[I]));
end;

procedure TGSet<T>.Clear;
begin
  System.FillChar(FBits, SizeOf(FBits), 0);
end;

procedure TGSet<T>.Include(aValue: T);
begin
  FBits[(Integer(aValue) - LO_VALUE) shr INT_SIZE_LOG] :=
    FBits[(Integer(aValue) - LO_VALUE) shr INT_SIZE_LOG] or
          SizeUInt(1) shl ((Integer(aValue) - LO_VALUE) and INT_SIZE_MASK);
end;

procedure TGSet<T>.Exclude(aValue: T);
begin
  FBits[(Integer(aValue) - LO_VALUE) shr INT_SIZE_LOG] :=
    FBits[(Integer(aValue) - LO_VALUE) shr INT_SIZE_LOG] and not
          (SizeUInt(1) shl ((Integer(aValue) - LO_VALUE) and INT_SIZE_MASK));
end;

procedure TGSet<T>.IncludeArray(const a: array of T);
var
  I: Integer;
begin
  for I := 0 to System.High(a) do
    Include(a[I]);
end;

procedure TGSet<T>.ExcludeArray(const a: array of T);
var
  I: Integer;
begin
  for I := 0 to System.High(a) do
    Exclude(a[I]);
end;

function TGSet<T>.Contains(aValue: T): Boolean;
begin
  Result :=
    FBits[(Integer(aValue) - LO_VALUE) shr INT_SIZE_LOG] and
          (SizeUInt(1) shl ((Integer(aValue) - LO_VALUE) and INT_SIZE_MASK)) <> 0;
end;

procedure TGSet<T>.Turn(aValue: T; aOn: Boolean);
begin
  if aOn then
    Include(aValue)
  else
    Exclude(aValue);
end;

function TGSet<T>.Intersecting(const aSet: TGSet<T>): Boolean;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if FBits[I] and aSet.FBits[I] <> 0 then
      exit(True);
  Result := False;
end;

procedure TGSet<T>.Intersect(const aSet: TGSet<T>);
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] and aSet.FBits[I];
end;

procedure TGSet<T>.Join(const aSet: TGSet<T>);
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] or aSet.FBits[I];
end;

procedure TGSet<T>.Subtract(const aSet: TGSet<T>);
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] and not aSet.FBits[I];
end;

procedure TGSet<T>.SymmetricSubtract(const aSet: TGSet<T>);
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    FBits[I] := FBits[I] xor aSet.FBits[I];
end;

class operator TGSet<T>.+(const L, R: TGSet<T>): TGSet<T>;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    Result.FBits[I] := L.FBits[I] or R.FBits[I];
end;

class operator TGSet<T>.-(const L, R: TGSet<T>): TGSet<T>;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    Result.FBits[I] := L.FBits[I] and not R.FBits[I];
end;

class operator TGSet<T>.*(const L, R: TGSet<T>): TGSet<T>;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    Result.FBits[I] := L.FBits[I] and R.FBits[I];
end;

class operator TGSet<T>.><(const L, R: TGSet<T>): TGSet<T>;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    Result.FBits[I] := L.FBits[I] xor R.FBits[I];
end;

class operator TGSet<T>.=(const L, R: TGSet<T>): Boolean; inline;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if L.FBits[I] <> R.FBits[I] then
      exit(False);
  Result := True;
end;

class operator TGSet<T>.<=(const L, R: TGSet<T>): Boolean; inline;
var
  I: Integer;
begin
  for I := 0 to Pred(LIMB_COUNT) do
    if L.FBits[I] <> L.FBits[I] and R.FBits[I] then
      exit(False);
  Result := True;
end;

class operator TGSet<T>.in(aValue: T; const aSet: TGSet<T>): Boolean;
begin
  Result := aSet.Contains(aValue);
end;

class operator TGSet<T>.Implicit(aValue: T): TGSet<T>;
begin
{$IFNDEF USE_TGSET_INITIALIZE}
  System.FillChar(Result.FBits, SizeOf(TBits), 0);
{$ENDIF}
  Result{%H-}.Include(aValue);
end;

class operator TGSet<T>.Explicit(aValue: T): TGSet<T>;
begin
{$IFNDEF USE_TGSET_INITIALIZE}
  System.FillChar(Result.FBits, SizeOf(TBits), 0);
{$ENDIF}
  Result{%H-}.Include(aValue);
end;

class operator TGSet<T>.Implicit(const a: array of T): TGSet<T>;
var
  I: Integer;
begin
{$IFNDEF USE_TGSET_INITIALIZE}
  System.FillChar(Result.FBits, SizeOf(TBits), 0);
{$ENDIF}
  for I := 0 to System.High(a) do
    Result{%H-}.Include(a[I]);
end;

class operator TGSet<T>.Explicit(const a: array of T): TGSet<T>;
var
  I: Integer;
begin
{$IFNDEF USE_TGSET_INITIALIZE}
  System.FillChar(Result.FBits, SizeOf(TBits), 0);
{$ENDIF}
  for I := 0 to System.High(a) do
    Result{%H-}.Include(a[I]);
end;

{ TGRecRange }

constructor TGRecRange<T>.Create(aFrom, aTo, aStep: T);
begin
  FCurrent := aFrom;
  FLast := aTo;
  FStep := aStep;
  FInLoop := False;
end;

function TGRecRange<T>.GetEnumerator: TGRecRange<T>;
begin
  Result := Self;
end;

function TGRecRange<T>.MoveNext: Boolean;
begin
  if FInLoop then
    begin
      if FLast - FStep >= FCurrent then
        begin
          FCurrent += FStep;
          exit(True);
        end;
      exit(False);
    end;
  FInLoop := True;
  Result := (FCurrent <= FLast) and (FStep > T(0));
end;

{ TGRecDownRange }

constructor TGRecDownRange<T>.Create(aFrom, aDownTo, aStep: T);
begin
  FCurrent := aFrom;
  FLast := aDownTo;
  FStep := aStep;
  FInLoop := False;
end;

function TGRecDownRange<T>.GetEnumerator: TGRecDownRange<T>;
begin
  Result := Self;
end;

function TGRecDownRange<T>.MoveNext: Boolean;
begin
  if FInLoop then
    begin
      if FLast + FStep <= FCurrent then
        begin
          FCurrent -= FStep;
          exit(True);
        end;
      exit(False);
    end;
  FInLoop := True;
  Result := (FCurrent >= FLast) and (FStep > T(0));
end;

function GRange<T>(aFrom, aTo: T; aStep: T): TGRecRange<T>;
begin
  Result := TGRecRange<T>.Create(aFrom, aTo, aStep);
end;

function GDownRange<T>(aFrom, aDownTo: T; aStep: T): TGRecDownRange<T>;
begin
  Result := TGRecDownRange<T>.Create(aFrom, aDownTo, aStep);
end;

procedure TurnSetElem<TSet, TElem>(var aSet: TSet; aElem: TElem; aOn: Boolean);
{$IF FPC_FULLVERSION>=30202}
begin
  if aOn then
    Include(aSet, aElem)
  else
    Exclude(aSet, aElem);
{$ELSE }
  procedure TurnElem(var ASet; const AItem; AOn: Boolean); inline;
  type
    TItem = 0..31;
    TItemSet = set of TItem;
  begin
    if AOn then
      Include(TItemSet(ASet), TItem(AItem))
    else
      Exclude(TItemSet(ASet), TItem(AItem))
  end;
begin
  TurnElem(aSet, aElem, AOn);
{$ENDIF}
end;

function MinOf3(a, b, c: SizeInt): SizeInt;
begin
  Result := a;
  if b < Result then
    Result := b;
  if c < Result then
    Result := c;
end;

function MaxOf3(a, b, c: SizeInt): SizeInt;
begin
  Result := a;
  if Result < b then
    Result := b;
  if Result < c then
    Result := c;
end;

end.

