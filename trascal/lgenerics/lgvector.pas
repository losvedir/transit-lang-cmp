{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic vector implementations.                                         *
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
unit lgVector;

{$mode objfpc}{$H+}
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
  lgAbstractContainer,
  lgStrConst;

type

  { TGVector }
  generic TGVector<T> = class(specialize TGCustomArrayContainer<T>)
  protected
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); virtual;
    function  GetMutable(aIndex: SizeInt): PItem; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure InsertItem(aIndex: SizeInt; const aValue: T);
    function  InsertArray(aIndex: SizeInt; const a: array of T): SizeInt;
    function  InsertContainer(aIndex: SizeInt; aContainer: TSpecContainer): SizeInt;
    function  InsertEnum(aIndex: SizeInt; e: IEnumerable): SizeInt;
    procedure FastSwap(L, R: SizeInt); inline;
    function  ExtractItem(aIndex: SizeInt): T;
    function  ExtractRange(aIndex, aCount: SizeInt): TArray;
    function  DeleteItem(aIndex: SizeInt): T; virtual;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt; virtual;
    function  DoSplit(aIndex: SizeInt): TGVector;
  public
  { appends aValue and returns it index; will raise ELGUpdateLock if instance in iteration }
    function  Add(const aValue: T): SizeInt;
  { appends all elements of array and returns count of added elements;
    will raise ELGUpdateLock if instance in iteration }
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration}
    procedure Insert(aIndex: SizeInt; const aValue: T);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
  { inserts all elements of array a into position aIndex and returns count of inserted elements;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration }
    function  InsertAll(aIndex: SizeInt; const a: array of T): SizeInt;
  { inserts all elements of e into position aIndex and returns count of inserted elements;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration}
    function  InsertAll(aIndex: SizeInt; e: IEnumerable): SizeInt;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  ExtractAll(aIndex, aCount: SizeInt): TArray;
  { deletes value in position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    procedure Delete(aIndex: SizeInt);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryDelete(aIndex: SizeInt): Boolean;
    function  DeleteLast: Boolean; inline;
    function  DeleteLast(out aValue: T): Boolean; inline;
  { deletes aCount elements(if possible) starting from aIndex and returns those count;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt;
  { will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  Split(aIndex: SizeInt): TGVector;
  { will return False if aIndex out of bounds or instance in iteration }
    function  TrySplit(aIndex: SizeInt; out aValue: TGVector): Boolean;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Mutable[aIndex: SizeInt]: PItem read GetMutable;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
  end;

  { TGObjectVector
    note: for equality comparision of items uses TObjectHelper from LGHelpers }
  generic TGObjectVector<T: class> = class(specialize TGVector<T>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure SetItem(aIndex: SizeInt; const aValue: T); override;
    procedure DoClear; override;
    function  DeleteItem(aIndex: SizeInt): T; override;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt; override;
    function  DoSplit(aIndex: SizeInt): TGObjectVector;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(const A: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
  { will raise EArgumentOutOfRangeException if aIndex out of bounds }
    function  Split(aIndex: SizeInt): TGObjectVector;
  { will return False if aIndex out of bounds }
    function  TrySplit(aIndex: SizeInt; out aValue: TGObjectVector): Boolean;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGThreadVector<T> = class
  public
  type
    TVector = specialize TGVector<T>;
  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
  { returns reference to encapsulated vector, after use this reference one must call UnLock }
    function  Lock: TVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(const aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt): Boolean;
  end;

  { TGLiteVector }

  generic TGLiteVector<T> = record
  private
  type
    TBuffer = specialize TGLiteDynBuffer<T>;
    TFake   = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};

  public
  type
    TEnumerator        = TBuffer.TEnumerator;
    TReverseEnumerator = TBuffer.TReverseEnumerator;
    TMutableEnumerator = TBuffer.TMutableEnumerator;
    TMutables          = TBuffer.TMutables;
    TReverse           = TBuffer.TReverse;
    PItem              = TBuffer.PItem;
    TArray             = TBuffer.TArray;

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetMutable(aIndex: SizeInt): PItem; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); inline;
    procedure InsertItem(aIndex: SizeInt; const aValue: T);
    function  DeleteItem(aIndex: SizeInt): T;
    function  ExtractRange(aIndex, aCount: SizeInt): TArray;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  GetMutableEnumerator: TMutableEnumerator; inline;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure MakeEmpty; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
  { appends aValue and returns it index }
    function  Add(const aValue: T): SizeInt;
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: specialize IGEnumerable<T>): SizeInt;
    function  AddAll(constref aVector: TGLiteVector): SizeInt;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; const aValue: T); inline;
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean; inline;
  { deletes and returns value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean; inline;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  ExtractAll(aIndex, aCount: SizeInt): TArray; inline;
    function  DeleteLast: Boolean; inline;
    function  DeleteLast(out aValue: T): Boolean; inline;
  { deletes aCount elements(if possible) starting from aIndex;
    returns count of deleted elements;
    will raise ELGListError if aIndex out of bounds }
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt; inline;
  { swaps items with indices aIdx1 and aIdx2; will raise ELGListError if any index out of bounds }
    procedure Swap(aIdx1, aIdx2: SizeInt);
  { does not checks range }
    procedure UncSwap(aIdx1, aIdx2: SizeInt); inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Mutable[aIndex: SizeInt]: PItem read GetMutable;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
  end;

  generic TGLiteThreadVector<T> = class
  public
  type
    TVector = specialize TGLiteVector<T>;
    PVector = ^TVector;

  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    function  Lock: PVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(const aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
  end;

  { TGLiteObjectVector }

  generic TGLiteObjectVector<T: class> = record
  private
  type
    TVector = specialize TGLiteVector<T>;

  public
  type
    TEnumerator        = TVector.TEnumerator;
    TReverseEnumerator = TVector.TReverseEnumerator;
    TReverse           = TVector.TReverse;
    TArray             = TVector.TArray;
    PItem              = TVector.PItem;

  private
    FVector: TVector;
    FOwnsObjects: Boolean;
    function  GetCount: SizeInt; inline;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure CheckFreeItems;
    class operator Initialize(var v: TGLiteObjectVector);
    class operator Copy(constref aSrc: TGLiteObjectVector; var aDst: TGLiteObjectVector);
  public
  type
    PVector = ^TVector;
    function  InnerVector: PVector; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
  { appends aValue and returns it index }
    function  Add(const aValue: T): SizeInt;inline;
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(constref aVector: TGLiteObjectVector): SizeInt; inline;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; const aValue: T); inline;
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean; inline;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean; inline;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  ExtractAll(aIndex, aCount: SizeInt): TArray; inline;
  { deletes value in position aIndex; will raise ELGListError if aIndex out of bounds}
    procedure Delete(aIndex: SizeInt); inline;
  { will return False if aIndex out of bounds }
    function  TryDelete(aIndex: SizeInt): Boolean; inline;
    function  DeleteLast: Boolean; inline;
    function  DeleteLast(out aValue: T): Boolean; inline;
  { deletes aCount elements(if possible) starting from aIndex;
    returns count of deleted elements;
    will raise ELGListError if aIndex out of bounds }
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectVector<T: class> = class
  public
  type
    TVector = specialize TGLiteObjectVector<T>;
    PVector = ^TVector;

  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    function  Lock: PVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(const aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt): Boolean;
  end;

  { TBoolVector: capacity is always a multiple of the bitness }
  TBoolVector = record
  private
  type
    TBits = array of SizeUInt;

  var
    FBits: TBits;
    function  GetCapacity: SizeInt; inline;
    function  GetBit(aIndex: SizeInt): Boolean; inline;
    function  GetBitUncheck(aIndex: SizeInt): Boolean; inline;
    procedure SetCapacity(aValue: SizeInt);
    procedure SetBit(aIndex: SizeInt; aValue: Boolean);
    procedure SetBitUncheck(aIndex: SizeInt; aValue: Boolean); inline;
  { returns count of significant limbs }
    function  SignLimbCount: SizeInt;
    class operator Copy(constref aSrc: TBoolVector; var aDst: TBoolVector); inline;
    class operator AddRef(var bv: TBoolVector); inline;
  public
  type
    TEnumerator = record
    private
      FBits: TBits;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      function  GetCurrent: SizeInt; inline;
      function  FindFirst: Boolean;
      procedure Init(const aBits: TBits);
    public
      function  MoveNext: Boolean; inline;
      property  Current: SizeInt read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FBits: TBits;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      function  GetCurrent: SizeInt; inline;
      function  FindLast: Boolean;
      procedure Init(const aBits: TBits);
    public
      function  MoveNext: Boolean;
      property  Current: SizeInt read GetCurrent;
    end;

    TReverse = record
    private
      FBits: TBits;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

    TIntArray = array of SizeInt;

  public
    procedure InitRange(aRange: SizeInt);
  { enumerates indices of set bits from lowest to highest }
    function  GetEnumerator: TEnumerator; inline;
  { enumerates indices of set bits from highest down to lowest }
    function  Reverse: TReverse; inline;
  { returns an array containing the indices of the set bits }
    function  ToArray: TIntArray;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit;
    procedure Clear; inline;
    procedure ClearBits; inline;
    procedure SetBits; inline;
    procedure ToggleBits;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean; inline;
    procedure SwapBits(var aVector: TBoolVector);
    procedure CopyBits(const aVector: TBoolVector; aCount: SizeInt);
    function  All: Boolean;
  { returns the lowest index of the set bit, -1, if no bit is set }
    function  Bsf: SizeInt;
  { returns the highest index of the set bit, -1, if no bit is set }
    function  Bsr: SizeInt;
  { returns the lowest index of the open bit, -1, if all bits are set }
    function  Lob: SizeInt;
  { changes the bit[aIndex] value to True if it was False and to False if it was True;
    returns old value; checks aIndex range }
    function  ToggleBit(aIndex: SizeInt): Boolean;
  { changes the bit[aIndex] value to True if it was False and to False if it was True;
    returns old value; does not checks aIndex range}
    function  UncToggleBit(aIndex: SizeInt): Boolean; inline;
    function  Intersecting(constref aValue: TBoolVector): Boolean;
  { returns the number of bits in the intersection with aValue }
    function  IntersectionPop(constref aValue: TBoolVector): SizeInt;
    function  Contains(constref aValue: TBoolVector): Boolean;
  { returns the number of bits that will be added when union with aValue }
    function  JoinGain(constref aValue: TBoolVector): SizeInt;
    procedure Join(constref aValue: TBoolVector);
    function  Union(constref aValue: TBoolVector): TBoolVector; inline;
    procedure Subtract(constref aValue: TBoolVector);
    function  Difference(constref aValue: TBoolVector): TBoolVector; inline;
    procedure Intersect(constref aValue: TBoolVector);
    function  Intersection(constref aValue: TBoolVector): TBoolVector; inline;
    procedure DisjunctJoin(constref aValue: TBoolVector);
    function  SymmDifference(constref aValue: TBoolVector): TBoolVector;
    function  Equals(constref aValue: TBoolVector): Boolean;
  { currently Capacity is always multiple of BitsizeOf(SizeUInt) }
    property  Capacity: SizeInt read GetCapacity write SetCapacity;
  { returns count of set bits }
    function  PopCount: SizeInt;
  { checks aIndex range }
    property  Bits[aIndex: SizeInt]: Boolean read GetBit write SetBit; default;
  { does not checks aIndex range }
    property  UncBits[aIndex: SizeInt]: Boolean read GetBitUncheck write SetBitUncheck;
  end;

  { TGVectorHelpUtil }

  generic TGVectorHelpUtil<T> = class
  private
  type
    THelper = specialize TGArrayHelpUtil<T>;
  public
  type
    TEqualityCompare = THelper.TEqualCompare;
    TVector          = class(specialize TGVector<T>);
    TLiteVector      = specialize TGLiteVector<T>;
    class procedure SwapItems(v: TVector; L, R: SizeInt); static;
    class procedure SwapItems(var v: TLiteVector; L, R: SizeInt); static; inline;
    class procedure Reverse(v: TVector); static; inline;
    class procedure Reverse(var v: TLiteVector); static; inline;
    class procedure RandomShuffle(v: TVector); static; inline;
    class procedure RandomShuffle(var v: TLiteVector); static; inline;
    class function  SequentSearch(v: TVector; const aValue: T; c: TEqualityCompare): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T; c: TEqualityCompare): SizeInt;
                    static; inline;
  end;

  { TGBaseVectorHelper
      functor TCmpRel(comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean }
  generic TGBaseVectorHelper<T, TCmpRel> = class
  private
  type
    THelper = specialize TGBaseArrayHelper<T, TCmpRel>;
  public
  type
    TVector     = class(specialize TGVector<T>);
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; const aValue: T): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; const aValue: T): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; const aValue: T): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean; static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector): Boolean; static;
    class function  Same(constref A, B: TLiteVector): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { Pascal translation of Orson Peters' PDQSort algorithm }
    class procedure PDQSort(v: TVector; o: TSortOrder = soAsc); static;
    class procedure PDQSort(var v: TLiteVector; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently PDQSort}
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector): TLiteVector.TArray; static; inline;
  end;

  { TGVectorHelper assumes that type T implements TCmpRel }
  generic TGVectorHelper<T> = class(specialize TGBaseVectorHelper<T, T>);

  { TGComparableVectorHelper assumes that type T defines comparison operators }
  generic TGComparableVectorHelper<T> = class
  private
  type
    THelper = specialize TGComparableArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    class procedure Reverse(v: TVector); static; inline;
    class procedure Reverse(var v: TLiteVector); static; inline;
    class procedure RandomShuffle(v: TVector); static; inline;
    class procedure RandomShuffle(var v: TLiteVector); static; inline;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; const aValue: T): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; const aValue: T): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; const aValue: T): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean; static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional; static; inline; //constref ?
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector): Boolean; static;
    class function  Same(constref A, B: TLiteVector): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { Pascal translation of Orson Peters' PDQSort algorithm }
    class procedure PDQSort(v: TVector; o: TSortOrder = soAsc); static;
    class procedure PDQSort(var v: TLiteVector; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently PDQSort}
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector): TLiteVector.TArray; static; inline;
  end;

  { TGRegularVectorHelper: with regular comparator }
  generic TGRegularVectorHelper<T> = class
  private
  type
    THelper   = specialize TGRegularArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TLess       = specialize TGLessCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; const aValue: T; c: TLess): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T; c: TLess): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; const aValue: T; c: TLess): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; const aValue: T; c: TLess): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TLess): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TLess): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TLess): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TLess): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TLess): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TLess): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TLess): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TLess): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TLess): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TLess): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TLess): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TLess): Boolean;
                    static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TLess): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TLess): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TLess): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TLess): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TLess): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TLess): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TLess): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { Pascal translation of Orson Peters' PDQSort algorithm }
    class procedure PDQSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static;
    class procedure PDQSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently PDQSort }
    class procedure Sort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TLess): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TLess): TLiteVector.TArray; static; inline;
  end;

  { TGDelegatedVectorHelper: with delegated comparator }
  generic TGDelegatedVectorHelper<T> = class
  private
  type
    THelper = specialize TGDelegatedArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TOnLess     = specialize TGOnLessCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; const aValue: T; c: TOnLess): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T; c: TOnLess): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; const aValue: T; c: TOnLess): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; const aValue: T; c: TOnLess): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TOnLess): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector; c: TOnLess): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TOnLess): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TOnLess): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TOnLess): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TOnLess): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TOnLess): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TOnLess): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TOnLess): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TOnLess): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TOnLess): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TOnLess): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TOnLess): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TOnLess): Boolean;
                    static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TOnLess): Boolean;
                    static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TOnLess): Boolean;
                    static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TOnLess): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TOnLess): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TOnLess): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TOnLess): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TOnLess): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TOnLess): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
  { Pascal translation of Orson Peters' PDQSort algorithm }
    class procedure PDQSort(v: TVector; c: TOnLess; o: TSortOrder = soAsc); static;
    class procedure PDQSort(var v: TLiteVector; c: TOnLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently PDQSort }
    class procedure Sort(v: TVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TOnLess; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TOnLess): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TOnLess): TLiteVector.TArray; static; inline;
  end;

  { TGNestedVectorHelper: with nested comparator }
  generic TGNestedVectorHelper<T> = class
  private
  type
    THelper = specialize TGNestedArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TLess       = specialize TGNestLessCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; const aValue: T; c: TLess): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; const aValue: T; c: TLess): SizeInt; static;
                    inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; const aValue: T; c: TLess): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; const aValue: T; c: TLess): SizeInt; static;
                    inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TLess): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector; c: TLess): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TLess): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TLess): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TLess): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TLess): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TLess): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TLess): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TLess): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TLess): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TLess): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TLess): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TLess): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TLess): Boolean;
                    static; inline;
    { returns V's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TLess): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TLess): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TLess): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TLess): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TLess): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TLess): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TLess): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TLess): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TLess): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { Pascal translation of Orson Peters' PDQSort algorithm }
    class procedure PDQSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static;
    class procedure PDQSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently PDQSort }
    class procedure Sort(v: TVector; c: TLess; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TLess; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TLess): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TLess): TVector.TArray; static; inline;
  end;

  { TGOrdVectorHelper: for ordinal types only }
  generic TGOrdVectorHelper<T> = class
  private
  type
    THelper = specialize TGOrdinalArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TArray = THelper.TArray;
    class procedure RadixSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure RadixSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
    class procedure RadixSort(v: TVector; var aBuf: TArray; o: TSortOrder = soAsc); static; inline;
    class procedure RadixSort(var v: TLiteVector; var aBuf: TArray; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  end;

  { TGRadixVectorSorter provides LSD radix sort;
      TKey is the type for which LSD radix sort is appropriate.
      TMap must provide class function GetKey([const[ref]] aItem: T): TKey; }
  generic TGRadixVectorSorter<T, TKey, TMap> = class
  private
  type
    THelper = specialize TGRadixSorter<T, TKey, TMap>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TArray = THelper.TArray;
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(v: TVector; var aBuf: TArray; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; var aBuf: TArray; o: TSortOrder = soAsc); static; inline;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGVector }

function TGVector.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := FItems[aIndex];
end;

procedure TGVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  //CheckInIteration;
  CheckIndexRange(aIndex);
  FItems[aIndex] := aValue;
end;

function TGVector.GetMutable(aIndex: SizeInt): PItem;
begin
  CheckIndexRange(aIndex);
  Result := @FItems[aIndex];
end;

function TGVector.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := @FItems[aIndex];
end;

procedure TGVector.InsertItem(aIndex: SizeInt; const aValue: T);
begin
  if aIndex < ElemCount then
    begin
      ItemAdding;
      System.Move(FItems[aIndex], FItems[Succ(aIndex)], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[aIndex], SizeOf(T), 0);
      FItems[aIndex] := aValue;
      Inc(FCount);
    end
  else
    Append(aValue);
end;

function TGVector.InsertArray(aIndex: SizeInt; const a: array of T): SizeInt;
begin
  if aIndex < ElemCount then
    begin
      Result := System.Length(a);
      if Result > 0 then
        begin
          EnsureCapacity(ElemCount + Result);
          System.Move(FItems[aIndex], FItems[aIndex + Result], (ElemCount - aIndex) * SizeOf(T));
          if IsManagedType(T) then
            begin
              System.FillChar(FItems[aIndex], Result * SizeOf(T), 0);
              TCopyHelper.CopyItems(@a[0], @FItems[aIndex], Result);
            end
          else
            System.Move(a[0], FItems[aIndex], Result * SizeOf(T));
          FCount += Result;
        end;
    end
  else
    Result := AppendArray(a);
end;

function TGVector.InsertContainer(aIndex: SizeInt; aContainer: TSpecContainer): SizeInt;
begin
  if aIndex < ElemCount then
    begin
      Result := aContainer.Count;
      if Result > 0 then
        begin
          EnsureCapacity(ElemCount + Result);
          System.Move(FItems[aIndex], FItems[aIndex + Result], SizeOf(T) * (ElemCount - aIndex));
          if IsManagedType(T) then
            System.FillChar(FItems[aIndex], SizeOf(T) * Result, 0);
          if aContainer <> Self then
            aContainer.CopyItems(@FItems[aIndex])
          else
            if IsManagedType(T) then
              begin
                TCopyHelper.CopyItems(@FItems[0], @FItems[aIndex], aIndex);
                TCopyHelper.CopyItems(@FItems[aIndex + Result], @FItems[aIndex + aIndex], Result - aIndex);
              end
            else
              begin
                System.Move(FItems[0], FItems[aIndex], aIndex * SizeOf(T));
                System.Move(FItems[aIndex + Result], FItems[aIndex + aIndex], (Result - aIndex) * SizeOf(T));
              end;
          FCount += Result;
        end;
    end
  else
    Result := AppendContainer(aContainer);
end;

function TGVector.InsertEnum(aIndex: SizeInt; e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecContainer then
    Result := InsertContainer(aIndex, TSpecContainer(o))
  else
    Result := InsertArray(aIndex, e.ToArray);
end;

procedure TGVector.FastSwap(L, R: SizeInt);
var
  v: TFake;
begin
  v := TFake(FItems[L]);
  TFake(FItems[L]) := TFake(FItems[R]);
  TFake(FItems[R]) := v;
end;

function TGVector.ExtractItem(aIndex: SizeInt): T;
begin
  Result := FItems[aIndex];
  if IsManagedType(T) then
    FItems[aIndex] := Default(T);
  Dec(FCount);
  if aIndex < ElemCount then
    begin
      System.Move(FItems[Succ(aIndex)], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[ElemCount], SizeOf(T), 0);
    end;
end;

function TGVector.ExtractRange(aIndex, aCount: SizeInt): TArray;
begin
  if aCount < 0 then
    aCount := 0;
  aCount := Math.Min(aCount, ElemCount - aIndex);
  System.SetLength(Result, aCount);
  if aCount > 0 then
    begin
      System.Move(FItems[aIndex], Result[0], SizeOf(T) * aCount);
      FCount -= aCount;
      if ElemCount - aIndex > 0 then
        System.Move(FItems[aIndex + aCount], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[ElemCount], SizeOf(T) * aCount, 0);
    end;
end;

function TGVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

function TGVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, ElemCount - aIndex);
  if Result > 0 then
    begin
      if IsManagedType(T) then
        for I := aIndex to Pred(aIndex + Result) do
          FItems[I] := Default(T);
      FCount -= Result;
      if ElemCount - aIndex > 0 then
        System.Move(FItems[aIndex + Result], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[ElemCount], SizeOf(T) * Result, 0);
    end;
end;

function TGVector.DoSplit(aIndex: SizeInt): TGVector;
var
  RCount: SizeInt;
begin
  RCount := ElemCount - aIndex;
  Result := TGVector.Create(RCount);
  System.Move(FItems[aIndex], Result.FItems[0], SizeOf(T) * RCount);
  if IsManagedType(T) then
    System.FillChar(FItems[aIndex], SizeOf(T) * RCount, 0);
  Result.FCount := RCount;
  FCount -= RCount;
end;

function TGVector.Add(const aValue: T): SizeInt;
begin
  CheckInIteration;
  Result := Append(aValue);
end;

function TGVector.AddAll(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGVector.AddAll(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := AppendEnumerable(e)
  else
    begin
      Result := 0;
      e.Any;
      UpdateLockError;
    end;
end;

procedure TGVector.Insert(aIndex: SizeInt; const aValue: T);
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  InsertItem(aIndex, aValue);
end;

function TGVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  Result := not InIteration and IndexInInsertRange(aIndex);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGVector.InsertAll(aIndex: SizeInt; const a: array of T): SizeInt;
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  Result := InsertArray(aIndex, a);
end;

function TGVector.InsertAll(aIndex: SizeInt; e: IEnumerable): SizeInt;
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  Result := InsertEnum(aIndex, e);
end;

function TGVector.Extract(aIndex: SizeInt): T;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := ExtractItem(aIndex);
end;

function TGVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    aValue := ExtractItem(aIndex);
end;

function TGVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := ExtractRange(aIndex, aCount);
end;

procedure TGVector.Delete(aIndex: SizeInt);
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  DeleteItem(aIndex);
end;

function TGVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    DeleteItem(aIndex);
end;

function TGVector.DeleteLast: Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      DeleteItem(Pred(ElemCount));
      exit(True);
    end;
  Result := False;
end;

function TGVector.DeleteLast(out aValue: T): Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      aValue := ExtractItem(Pred(ElemCount));
      exit(True);
    end;
  Result := False;
end;

function TGVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DeleteRange(aIndex, aCount);
end;

function TGVector.Split(aIndex: SizeInt): TGVector;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DoSplit(aIndex);
end;

function TGVector.TrySplit(aIndex: SizeInt; out aValue: TGVector): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    aValue := DoSplit(aIndex);
end;

{ TGObjectVector }

procedure TGObjectVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  //CheckInIteration;
  CheckIndexRange(aIndex);
  if FItems[aIndex] <> aValue then
    begin
      if OwnsObjects then
        FItems[aIndex].Free;
      FItems[aIndex] := aValue;
    end;
end;

procedure TGObjectVector.DoClear;
var
  I: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    for I := 0 to Pred(ElemCount) do
      FItems[I].Free;
  inherited;
end;

function TGObjectVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := inherited DeleteItem(aIndex);
  if OwnsObjects then
    Result.Free;
end;

function TGObjectVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, ElemCount - aIndex);
  if Result > 0 then
    begin
      if OwnsObjects then
        for I := aIndex to Pred(aIndex + Result) do
          FItems[I].Free;
      FCount -= Result;
      System.Move((@FItems[aIndex + Result])^, FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
    end;
end;

function TGObjectVector.DoSplit(aIndex: SizeInt): TGObjectVector;
var
  RCount: SizeInt;
begin
  RCount := ElemCount - aIndex;
  Result := TGObjectVector.Create(RCount, OwnsObjects);
  System.Move((@FItems[aIndex])^, Result.FItems[0], SizeOf(T) * RCount);
  Result.FCount := RCount;
  FCount -= RCount;
end;

constructor TGObjectVector.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(const A: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

function TGObjectVector.Split(aIndex: SizeInt): TGObjectVector;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DoSplit(aIndex);
end;

function TGObjectVector.TrySplit(aIndex: SizeInt; out aValue: TGObjectVector): Boolean;
begin
  Result := not InIteration and (aIndex >= 0) and (aIndex < ElemCount);
  if Result then
    aValue := DoSplit(aIndex);
end;

procedure TGThreadVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadVector.Create;
begin
  System.InitCriticalSection(FLock);
  FVector := TVector.Create;
end;

destructor TGThreadVector.Destroy;
begin
  DoLock;
  try
    FVector.Free;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGThreadVector.Lock: TVector;
begin
  Result := FVector;
  DoLock;
end;

procedure TGThreadVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGThreadVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGThreadVector.Add(const aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryDelete(aIndex);
  finally
    UnLock;
  end;
end;

{ TGLiteVector }

function TGLiteVector.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteVector.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.GetMutable(aIndex: SizeInt): PItem;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := @FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := @FBuffer.FItems[aIndex];
end;

procedure TGLiteVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    FBuffer.FItems[aIndex] := aValue
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteVector.InsertItem(aIndex: SizeInt; const aValue: T);
begin
  if aIndex < Count then
    begin
      FBuffer.ItemAdding;
      System.Move(FBuffer.FItems[aIndex], FBuffer.FItems[Succ(aIndex)], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[aIndex], SizeOf(T), 0);
      FBuffer.FItems[aIndex] := aValue;
      Inc(FBuffer.FCount);
    end
  else
    Add(aValue);
end;

function TGLiteVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := FBuffer.FItems[aIndex];
  if IsManagedType(T) then
    FBuffer.FItems[aIndex] := Default(T);
  Dec(FBuffer.FCount);
  if aIndex < Count then
    begin
      System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[Count], SizeOf(T), 0);
    end;
end;

function TGLiteVector.ExtractRange(aIndex, aCount: SizeInt): TArray;
begin
  if aCount < 0 then
    aCount := 0;
  aCount := Math.Min(aCount, Count - aIndex);
  System.SetLength(Result, aCount);
  if aCount > 0 then
    begin
      System.Move(FBuffer.FItems[aIndex], Pointer(Result)^, SizeOf(T) * aCount);
      FBuffer.FCount -= aCount;
      if Count - aIndex > 0 then
        System.Move(FBuffer.FItems[aIndex + aCount], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[Count], SizeOf(T) * aCount, 0);
    end;
end;

function TGLiteVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, Count - aIndex);
  if Result > 0 then
    begin
      if IsManagedType(T) then
        FBuffer.FinalizeItems(aIndex, Result);
      FBuffer.FCount -= Result;
      if Count - aIndex > 0 then
        System.Move(FBuffer.FItems[aIndex + Result], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[Count], SizeOf(T) * Result, 0);
    end;
end;

function TGLiteVector.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteVector.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteVector.GetMutableEnumerator: TMutableEnumerator;
begin
  Result := FBuffer.GetMutableEnumerator;
end;

function TGLiteVector.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteVector.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteVector.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteVector.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteVector.MakeEmpty;
begin
  FBuffer.MakeEmpty;
end;

function TGLiteVector.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteVector.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteVector.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteVector.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

function TGLiteVector.Add(const aValue: T): SizeInt;
begin
  Result := FBuffer.PushLast(aValue);
end;

function TGLiteVector.AddAll(const a: array of T): SizeInt;
var
  I, J: SizeInt;
begin
  Result := System.Length(a);
  if Result = 0 then exit;
  EnsureCapacity(Count + Result);
  I := Count;
  with FBuffer do
    begin
      if IsManagedType(T) then
        for J := 0 to System.High(a) do
          begin
            FItems[I] := a[J];
            Inc(I);
          end
      else
        System.Move(a[0], FItems[I], Result * SizeOf(T));
      FCount += Result;
    end;
end;

function TGLiteVector.AddAll(e: specialize IGEnumerable<T>): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        FBuffer.PushLast(Current);
    finally
      Free;
    end;
  Result := Count - Result;
end;

function TGLiteVector.AddAll(constref aVector: TGLiteVector): SizeInt;
var
  I, J: SizeInt;
begin
  Result := aVector.Count;
  if Result = 0 then exit;
  EnsureCapacity(Count + Result);
  I := Count;
  with FBuffer do
    begin
      if IsManagedType(T) then
        for J := 0 to Pred(aVector.Count) do
          begin
            FItems[I] := aVector.FBuffer.FItems[J];
            Inc(I);
          end
      else
        System.Move(Pointer(aVector.FBuffer.FItems)^, FItems[I], Result * SizeOf(T));
      FCount += Result;
    end;
end;

procedure TGLiteVector.Insert(aIndex: SizeInt; const aValue: T);
begin
  if SizeUInt(aIndex) <= SizeUInt(Count) then
    InsertItem(aIndex, aValue)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) <= SizeUInt(Count);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGLiteVector.Extract(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := DeleteItem(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) < SizeUInt(Count);
  if Result then
    aValue := DeleteItem(aIndex);
end;

function TGLiteVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := ExtractRange(aIndex, aCount)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.DeleteLast: Boolean;
begin
  if NonEmpty then
    begin
      DeleteItem(Pred(Count));
      exit(True);
    end;
  Result := False;
end;

function TGLiteVector.DeleteLast(out aValue: T): Boolean;
begin
  if NonEmpty then
    begin
      aValue := DeleteItem(Pred(Count));
      exit(True);
    end;
  Result := False;
end;

function TGLiteVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := DeleteRange(aIndex, aCount)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteVector.Swap(aIdx1, aIdx2: SizeInt);
var
  Tmp: TFake;
begin
   if SizeUInt(aIdx1) < SizeUInt(Count) then
     if SizeUInt(aIdx2) < SizeUInt(Count) then
       begin
         Tmp := TFake(FBuffer.FItems[aIdx1]);
         TFake(FBuffer.FItems[aIdx1]) := TFake(FBuffer.FItems[aIdx2]);
         TFake(FBuffer.FItems[aIdx2]) := Tmp;
       end
     else
       raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIdx2])
   else
     raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIdx1]);
end;

procedure TGLiteVector.UncSwap(aIdx1, aIdx2: SizeInt);
var
  Tmp: TFake;
begin
  Tmp := TFake(FBuffer.FItems[aIdx1]);
  TFake(FBuffer.FItems[aIdx1]) := TFake(FBuffer.FItems[aIdx2]);
  TFake(FBuffer.FItems[aIdx2]) := Tmp;
end;

{ TGLiteThreadVector }

procedure TGLiteThreadVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadVector.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadVector.Destroy;
begin
  DoLock;
  try
    Finalize(FVector);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGLiteThreadVector.Lock: PVector;
begin
  Result := @FVector;
  DoLock;
end;

procedure TGLiteThreadVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGLiteThreadVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.Add(const aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

{ TGLiteObjectVector }

function TGLiteObjectVector.GetCount: SizeInt;
begin
  Result := FVector.Count;
end;

function TGLiteObjectVector.GetCapacity: SizeInt;
begin
  Result := FVector.Capacity;
end;

function TGLiteObjectVector.GetItem(aIndex: SizeInt): T;
begin
  Result := FVector.GetItem(aIndex);
end;

function TGLiteObjectVector.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := FVector.GetUncMutable(aIndex);
end;

procedure TGLiteObjectVector.SetItem(aIndex: SizeInt; const aValue: T);
var
  p: PItem;
begin
  p := FVector.GetMutable(aIndex);
  if p^ <> aValue then
    begin
      if OwnsObjects then
        p^.Free;
      p^ := aValue;
    end;
end;

procedure TGLiteObjectVector.CheckFreeItems;
var
  I: SizeInt;
  LocItems: PItem;
begin
  if OwnsObjects then
    begin
      LocItems := PItem(FVector.FBuffer.FItems);
      for I := 0 to Pred(Count) do
        LocItems[I].Free;
    end;
end;

class operator TGLiteObjectVector.Initialize(var v: TGLiteObjectVector);
begin
  v.OwnsObjects := True;
end;

class operator TGLiteObjectVector.Copy(constref aSrc: TGLiteObjectVector; var aDst: TGLiteObjectVector);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FVector := aSrc.FVector;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectVector.InnerVector: PVector;
begin
  Result := @FVector;
end;

function TGLiteObjectVector.GetEnumerator: TEnumerator;
begin
  Result := FVector.GetEnumerator;
end;

function TGLiteObjectVector.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FVector.GetReverseEnumerator;
end;

function TGLiteObjectVector.Reverse: TReverse;
begin
  Result := FVector.Reverse;
end;

function TGLiteObjectVector.ToArray: TArray;
begin
  Result := FVector.ToArray;
end;

procedure TGLiteObjectVector.Clear;
begin
  CheckFreeItems;
  FVector.Clear;
end;

function TGLiteObjectVector.IsEmpty: Boolean;
begin
  Result := FVector.IsEmpty;
end;

function TGLiteObjectVector.NonEmpty: Boolean;
begin
  Result := FVector.NonEmpty;
end;

procedure TGLiteObjectVector.EnsureCapacity(aValue: SizeInt);
begin
  FVector.EnsureCapacity(aValue)
end;

procedure TGLiteObjectVector.TrimToFit;
begin
  FVector.TrimToFit;
end;

function TGLiteObjectVector.Add(const aValue: T): SizeInt;
begin
  Result := FVector.Add(aValue);
end;

function TGLiteObjectVector.AddAll(const a: array of T): SizeInt;
begin
  Result := FVector.AddAll(a);
end;

function TGLiteObjectVector.AddAll(constref aVector: TGLiteObjectVector): SizeInt;
begin
  Result := FVector.AddAll(aVector.FVector);
end;

procedure TGLiteObjectVector.Insert(aIndex: SizeInt; const aValue: T);
begin
  FVector.Insert(aIndex, aValue);
end;

function TGLiteObjectVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  Result := FVector.TryInsert(aIndex, aValue);
end;

function TGLiteObjectVector.Extract(aIndex: SizeInt): T;
begin
  Result := FVector.Extract(aIndex);
end;

function TGLiteObjectVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := FVector.TryExtract(aIndex, aValue);
end;

function TGLiteObjectVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  Result := FVector.ExtractAll(aIndex, aCount);
end;

procedure TGLiteObjectVector.Delete(aIndex: SizeInt);
var
  v: T;
begin
  v := FVector.Extract(aIndex);
  if OwnsObjects then
    v.Free;
end;

function TGLiteObjectVector.TryDelete(aIndex: SizeInt): Boolean;
var
  v: T;
begin
  Result := FVector.TryExtract(aIndex, v);
  if Result and OwnsObjects then
    v.Free;
end;

function TGLiteObjectVector.DeleteLast: Boolean;
var
  v: T;
begin
  Result := FVector.DeleteLast(v);
  if Result and OwnsObjects then
    v.Free;
end;

function TGLiteObjectVector.DeleteLast(out aValue: T): Boolean;
begin
  Result := FVector.DeleteLast(aValue);
end;

function TGLiteObjectVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
var
  a: TArray;
  v: T;
begin
  if OwnsObjects then
    begin
      a := FVector.ExtractAll(aIndex, aCount);
      Result := System.Length(a);
      for v in a do
        v.Free;
    end
  else
    Result := FVector.DeleteAll(aIndex, aCount);
end;

{ TGLiteThreadObjectVector }

procedure TGLiteThreadObjectVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectVector.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadObjectVector.Destroy;
begin
  DoLock;
  try
    Finalize(FVector);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGLiteThreadObjectVector.Lock: PVector;
begin
  Result := @FVector;
  DoLock;
end;

procedure TGLiteThreadObjectVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGLiteThreadObjectVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.Add(const aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryDelete(aIndex);
  finally
    UnLock;
  end;
end;

{ TBoolVector.TEnumerator }

function TBoolVector.TEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TBoolVector.TEnumerator.FindFirst: Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.Length(FBits)) do
    if FBits[I] <> 0 then
      begin
        FBitIndex := BsfSizeUInt(FBits[I]);
        FLimbIndex := I;
        FCurrLimb := FBits[I] and not(SizeUInt(1) shl FBitIndex);
        exit(True);
      end;
  Result := False;
end;

procedure TBoolVector.TEnumerator.Init(const aBits: TBits);
begin
  FBits := aBits;
  FLimbIndex := NULL_INDEX;
  FBitIndex := NULL_INDEX;
end;

function TBoolVector.TEnumerator.MoveNext: Boolean;
begin
  if FLimbIndex <> NULL_INDEX then
    begin
      Result := False;
      repeat
        if FCurrLimb <> 0 then
          begin
            FBitIndex := BsfSizeUInt(FCurrLimb);
            FCurrLimb := FCurrLimb and not(SizeUInt(1) shl FBitIndex);
            exit(True);
          end
        else
          begin
            if FLimbIndex = System.High(FBits) then
              exit;
            Inc(FLimbIndex);
            FCurrLimb := FBits[FLimbIndex];
          end;
      until False;
    end
  else
    Result := FindFirst;
end;

{ TBoolVector.TReverseEnumerator }

function TBoolVector.TReverseEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TBoolVector.TReverseEnumerator.FindLast: Boolean;
var
  I: SizeInt;
begin
  for I := Pred(System.Length(FBits)) downto 0 do
    if FBits[I] <> 0 then
      begin
        FBitIndex := BsrSizeUInt(FBits[I]);
        FLimbIndex := I;
        FCurrLimb := FBits[I] and not(SizeUInt(1) shl FBitIndex);
        exit(True);
      end;
  Result := False;
end;

procedure TBoolVector.TReverseEnumerator.Init(const aBits: TBits);
begin
  FBits := aBits;
  FLimbIndex := NULL_INDEX;
  FBitIndex := NULL_INDEX;
end;

function TBoolVector.TReverseEnumerator.MoveNext: Boolean;
begin
  if FLimbIndex <> NULL_INDEX then
    begin
      Result := False;
      repeat
        if FCurrLimb <> 0 then
          begin
            FBitIndex := BsrSizeUInt(FCurrLimb);
            FCurrLimb := FCurrLimb and not(SizeUInt(1) shl FBitIndex);
            exit(True);
          end
        else
          begin
            if FLimbIndex = 0 then
              exit;
            Dec(FLimbIndex);
            FCurrLimb := FBits[FLimbIndex];
          end;
      until False;
    end
  else
    Result := FindLast;
end;

{ TBoolVector.TReverse }

function TBoolVector.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result.Init(FBits);
end;

{ TBoolVector }

function TBoolVector.GetCapacity: SizeInt;
begin
  Result := System.Length(FBits) shl INT_SIZE_LOG;
end;

function TBoolVector.GetBit(aIndex: SizeInt): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(System.Length(FBits) shl INT_SIZE_LOG) then
    Result := FBits[aIndex shr INT_SIZE_LOG] and (SizeUInt(1) shl (aIndex and INT_SIZE_MASK)) <> 0
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TBoolVector.GetBitUncheck(aIndex: SizeInt): Boolean;
begin
  Result := FBits[aIndex shr INT_SIZE_LOG] and (SizeUInt(1) shl (aIndex and INT_SIZE_MASK)) <> 0;
end;

procedure TBoolVector.SetCapacity(aValue: SizeInt);
begin
  if aValue < 0 then
    aValue := 0;
  if aValue <> Capacity then
    begin
      aValue := aValue shr INT_SIZE_LOG + Ord(aValue and INT_SIZE_MASK <> 0);
      if aValue <= MAX_CONTAINER_SIZE div SizeOf(SizeUInt) then
        System.SetLength(FBits, aValue)
      else
        raise ELGCapacityExceed.CreateFmt(SECapacityExceedFmt, [aValue]);
    end;
end;

procedure TBoolVector.SetBit(aIndex: SizeInt; aValue: Boolean);
begin
  if SizeUInt(aIndex) < SizeUInt(System.Length(FBits) shl INT_SIZE_LOG) then
    if aValue then
      FBits[aIndex shr INT_SIZE_LOG] := FBits[aIndex shr INT_SIZE_LOG] or
                                        SizeUInt(1) shl (aIndex and INT_SIZE_MASK)
    else
      FBits[aIndex shr INT_SIZE_LOG] := FBits[aIndex shr INT_SIZE_LOG] and
                                        not(SizeUInt(1) shl (aIndex and INT_SIZE_MASK))
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TBoolVector.SetBitUncheck(aIndex: SizeInt; aValue: Boolean);
begin
  if aValue then
    FBits[aIndex shr INT_SIZE_LOG] := FBits[aIndex shr INT_SIZE_LOG] or
                                      SizeUInt(1) shl (aIndex and INT_SIZE_MASK)
  else
    FBits[aIndex shr INT_SIZE_LOG] := FBits[aIndex shr INT_SIZE_LOG] and
                                      not(SizeUInt(1) shl (aIndex and INT_SIZE_MASK));
end;

function TBoolVector.SignLimbCount: SizeInt;
var
  I: SizeInt;
begin
  for I := System.High(FBits) downto 0 do
    if FBits[I] <> 0 then
      exit(Succ(I));
  Result := 0;
end;

class operator TBoolVector.Copy(constref aSrc: TBoolVector; var aDst: TBoolVector);
begin
  aDst.FBits := System.Copy(aSrc.FBits);
end;

class operator TBoolVector.AddRef(var bv: TBoolVector);
begin
  bv.FBits := System.Copy(bv.FBits);
end;

procedure TBoolVector.InitRange(aRange: SizeInt);
var
  msb: SizeInt;
begin
  //FBits := nil;
  if aRange > 0 then
    begin
      msb := aRange and INT_SIZE_MASK;
      aRange := aRange shr INT_SIZE_LOG  + Ord(msb <> 0);
      if aRange <> System.Length(FBits) then
        System.SetLength(FBits, aRange);
      System.FillChar(Pointer(FBits)^, aRange * SizeOf(SizeUInt), $ff);
      if msb <> 0 then
        FBits[Pred(aRange)] := FBits[Pred(aRange)] shr (BitsizeOf(SizeUint) - msb);
    end;
end;

function TBoolVector.GetEnumerator: TEnumerator;
begin
  Result.Init(FBits);
end;

function TBoolVector.Reverse: TReverse;
begin
  Result.FBits := FBits;
end;

function TBoolVector.ToArray: TIntArray;
var
  I, Pos: SizeInt;
begin
  System.SetLength(Result, PopCount);
  Pos := 0;
  for I in Self do
    begin
      Result[Pos] := I;
      Inc(Pos);
    end;
end;

procedure TBoolVector.EnsureCapacity(aValue: SizeInt);
begin
  if Capacity < aValue then
    SetCapacity(aValue);
end;

procedure TBoolVector.TrimToFit;
var
  slCount: SizeInt;
begin
  slCount := SignLimbCount;
  if slCount <> System.Length(FBits) then
    System.SetLength(FBits, slCount);
end;

procedure TBoolVector.Clear;
begin
  FBits := nil;
end;

procedure TBoolVector.ClearBits;
begin
  System.FillChar(Pointer(FBits)^, System.Length(FBits) * SizeOf(SizeUInt), 0);
end;

procedure TBoolVector.SetBits;
begin
  System.FillChar(Pointer(FBits)^, System.Length(FBits) * SizeOf(SizeUInt), $ff);
end;

procedure TBoolVector.ToggleBits;
var
  I: SizeInt;
begin
  for I := 0 to Pred(Length(FBits)) do
    FBits[I] := not FBits[I];
end;

function TBoolVector.IsEmpty: Boolean;
var
  I: SizeUInt;
begin
  for I in FBits do
    if I <> 0 then
      exit(False);
  Result := True;
end;

function TBoolVector.NonEmpty: Boolean;
begin
  Result := not IsEmpty;
end;

procedure TBoolVector.SwapBits(var aVector: TBoolVector);
var
  tmp: Pointer;
begin
  tmp := Pointer(FBits);
  Pointer(FBits) := Pointer(aVector.FBits);
  Pointer(aVector.FBits) := tmp;
end;

procedure TBoolVector.CopyBits(const aVector: TBoolVector; aCount: SizeInt);
var
  I, J: SizeInt;
const
  MASK = System.High(SizeUInt);
  BIT_SIZE = BitSizeOf(SizeUInt);
begin
  if aCount > aVector.Capacity then aCount := aVector.Capacity; //todo: exception ???
  if (aCount < 1) or (Pointer(FBits) = Pointer(aVector.FBits)) then exit;
  EnsureCapacity(aCount);
  J := aCount shr INT_SIZE_LOG;
  for I := 0 to Pred(J) do
    FBits[I] := aVector.FBits[I];
  I := aCount and INT_SIZE_MASK;
  if I <> 0 then
    FBits[J] := FBits[J] and (MASK shl I) or aVector.FBits[J] and (MASK shr (BIT_SIZE - I));
end;

function TBoolVector.All: Boolean;
var
  I: SizeUInt;
begin
  for I in FBits do
    if I <> High(SizeUInt) then
      exit(False);
  Result := True;
end;

function TBoolVector.Bsf: SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBits) do
    if FBits[I] <> 0 then
      exit(
        {$IF DEFINED(CPU64)}
          I shl INT_SIZE_LOG + ShortInt(BsfQWord(FBits[I]))
        {$ELSEIF DEFINED(CPU32)}
          I shl INT_SIZE_LOG + ShortInt(BsfDWord(FBits[I]))
        {$ELSE}
          I shl INT_SIZE_LOG + ShortInt(BsfWord(FBits[I]))
        {$ENDIF});
  Result := NULL_INDEX;
end;

function TBoolVector.Bsr: SizeInt;
var
  I: SizeInt;
begin
  for I := System.High(FBits) downto 0 do
    if FBits[I] <> 0 then
      exit(
        {$IF DEFINED(CPU64)}
          I shl INT_SIZE_LOG + ShortInt(BsrQWord(FBits[I]))
        {$ELSEIF DEFINED(CPU32)}
          I shl INT_SIZE_LOG + ShortInt(BsrDWord(FBits[I]))
        {$ELSE}
          I shl INT_SIZE_LOG + ShortInt(BsrWord(FBits[I]))
        {$ENDIF});
  Result := NULL_INDEX;
end;

function TBoolVector.Lob: SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBits) do
    if FBits[I] <> High(SizeUInt) then
      exit(
        {$IF DEFINED(CPU64)}
          I shl INT_SIZE_LOG + ShortInt(BsfQWord(not FBits[I]))
        {$ELSEIF DEFINED(CPU32)}
          I shl INT_SIZE_LOG + ShortInt(BsfQWord(not FBits[I]))
        {$ELSE}
          I shl INT_SIZE_LOG + ShortInt(BsfQWord(not FBits[I]))
        {$ENDIF});
  Result := NULL_INDEX;
end;

function TBoolVector.ToggleBit(aIndex: SizeInt): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(System.Length(FBits) shl INT_SIZE_LOG) then
    begin
      Result := (FBits[aIndex shr INT_SIZE_LOG] and (SizeUInt(1) shl (aIndex and INT_SIZE_MASK))) <> 0;
      FBits[aIndex shr INT_SIZE_LOG] :=
        FBits[aIndex shr INT_SIZE_LOG] xor (SizeUInt(1) shl (aIndex and INT_SIZE_MASK));
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TBoolVector.UncToggleBit(aIndex: SizeInt): Boolean;
var
  LimbIdx: SizeInt;
  Mask: SizeUInt;
begin
  LimbIdx := aIndex shr INT_SIZE_LOG;
  Mask := SizeUInt(1) shl (aIndex and INT_SIZE_MASK);
  Result := FBits[LimbIdx] and Mask <> 0;
  FBits[LimbIdx] := FBits[LimbIdx] xor Mask;
end;

function TBoolVector.Intersecting(constref aValue: TBoolVector): Boolean;
var
  I: SizeInt;
begin
  if @Self = @aValue then
    exit(NonEmpty);
  for I := 0 to Math.Min(System.High(FBits), System.High(aValue.FBits)) do
    if FBits[I] and aValue.FBits[I] <> 0 then
      exit(True);
  Result := False;
end;

function TBoolVector.IntersectionPop(constref aValue: TBoolVector): SizeInt;
var
  I, Len: SizeInt;
begin
  if @Self = @aValue then
    exit(PopCount);
  Len := Math.Min(System.Length(FBits), System.Length(aValue.FBits));
  I := 0;
  Result := 0;
  while I <= Len - 4 do
    begin
      Result += SizeInt(PopCnt(FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(FBits[I+1] and aValue.FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2] and aValue.FBits[I+2])) +
                SizeInt(PopCnt(FBits[I+3] and aValue.FBits[I+3]));
      Inc(I, 4);
    end;
  case Len - I of
    1:
      Result += SizeInt(PopCnt(FBits[I] and aValue.FBits[I]));
    2:
      Result += SizeInt(PopCnt(FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(FBits[I+1] and aValue.FBits[I+1]));
    3:
      Result += SizeInt(PopCnt(FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(FBits[I+1] and aValue.FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2] and aValue.FBits[I+2]));
  else
  end;
end;

function TBoolVector.Contains(constref aValue: TBoolVector): Boolean;
var
  I: SizeInt;
begin
  if @Self = @aValue then
    exit(True);
  for I := 0 to Math.Min(System.High(FBits), System.High(aValue.FBits)) do
    if FBits[I] or aValue.FBits[I] <> FBits[I] then
      exit(False);
  for I := System.Length(FBits) to System.High(aValue.FBits) do
    if aValue.FBits[I] <> 0 then
      exit(False);
  Result := True;
end;

function TBoolVector.JoinGain(constref aValue: TBoolVector): SizeInt;
var
  I, Len: SizeInt;
begin
  if @Self = @aValue then
    exit(0);
  Len := Math.Min(System.Length(FBits), System.Length(aValue.FBits));
  I := 0;
  Result := 0;
  while I <= Len - 4 do
    begin
      Result += SizeInt(PopCnt(not FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(not FBits[I+1] and aValue.FBits[I+1])) +
                SizeInt(PopCnt(not FBits[I+2] and aValue.FBits[I+2])) +
                SizeInt(PopCnt(not FBits[I+3] and aValue.FBits[I+3]));
      Inc(I, 4);
    end;
  case Len - I of
    1:
      begin
        Result += SizeInt(PopCnt(not FBits[I] and aValue.FBits[I]));
        I += 1;
      end;
    2:
      begin
        Result += SizeInt(PopCnt(not FBits[I  ] and aValue.FBits[I  ])) +
                  SizeInt(PopCnt(not FBits[I+1] and aValue.FBits[I+1]));
        I += 2;
      end;
    3:
      begin
        Result += SizeInt(PopCnt(not FBits[I  ] and aValue.FBits[I  ])) +
                  SizeInt(PopCnt(not FBits[I+1] and aValue.FBits[I+1])) +
                  SizeInt(PopCnt(not FBits[I+2] and aValue.FBits[I+2]));
        I += 3;
      end;
  else
  end;
  for I := I to System.High(aValue.FBits) do
    Result += SizeInt(PopCnt(aValue.FBits[I]));
end;

procedure TBoolVector.Join(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  if @Self = @aValue then
    exit;
  Len := aValue.SignLimbCount;
  if Len > System.Length(FBits) then
    System.SetLength(FBits,  Len);;
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] or aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] or aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] or aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] or aValue.FBits[I+3];
      Inc(I, 4);
    end;
  case Len - I of
    1:
      FBits[I  ] := FBits[I  ] or aValue.FBits[I];
    2:
      begin
        FBits[I  ] := FBits[I  ] or aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] or aValue.FBits[I+1];
      end;
    3:
      begin
        FBits[I  ] := FBits[I  ] or aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] or aValue.FBits[I+1];
        FBits[I+2] := FBits[I+2] or aValue.FBits[I+2];
      end;
  else
  end;
end;

function TBoolVector.Union(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Join(aValue);
end;

procedure TBoolVector.Subtract(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  if @Self = @aValue then
    begin
      ClearBits;
      exit;
    end;
  Len := Math.Min(System.Length(FBits), System.Length(aValue.FBits));
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] and not aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] and not aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] and not aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] and not aValue.FBits[I+3];
      Inc(I, 4);
    end;
  case Len - I of
    1:
      FBits[I  ] := FBits[I  ] and not aValue.FBits[I];
    2:
      begin
        FBits[I  ] := FBits[I  ] and not aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] and not aValue.FBits[I+1];
      end;
    3:
      begin
        FBits[I  ] := FBits[I  ] and not aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] and not aValue.FBits[I+1];
        FBits[I+2] := FBits[I+2] and not aValue.FBits[I+2];
      end;
  else
  end;
end;

function TBoolVector.Difference(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Subtract(aValue);
end;

procedure TBoolVector.Intersect(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  if @Self = @aValue then
    exit;
  Len := Math.Min(System.Length(FBits), System.Length(aValue.FBits));
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] and aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] and aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] and aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] and aValue.FBits[I+3];
      Inc(I, 4);
    end;
  case Len - I of
    1:
      FBits[I  ] := FBits[I  ] and aValue.FBits[I];
    2:
      begin
        FBits[I  ] := FBits[I  ] and aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] and aValue.FBits[I+1];
      end;
    3:
      begin
        FBits[I  ] := FBits[I  ] and aValue.FBits[I  ];
        FBits[I+1] := FBits[I+1] and aValue.FBits[I+1];
        FBits[I+2] := FBits[I+2] and aValue.FBits[I+2];
      end;
  else
  end;
  for I := Len to System.High(FBits) do
    FBits[I] := 0;
end;

function TBoolVector.Intersection(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Intersect(aValue);
end;

procedure TBoolVector.DisjunctJoin(constref aValue: TBoolVector);
var
  I, MinLen: SizeInt;
begin
  if @Self = @aValue then
    begin
      ClearBits;
      exit;
    end;
  MinLen := Math.Min(System.Length(FBits), System.Length(aValue.FBits));
  if System.Length(FBits) < System.Length(aValue.FBits) then
    System.SetLength(FBits,  System.Length(aValue.FBits));
  for I := 0 to Pred(MinLen) do
    FBits[I] := FBits[I] xor aValue.FBits[I];
  for I := MinLen to Pred(System.Length(aValue.FBits)) do
    FBits[I] := aValue.FBits[I];
end;

function TBoolVector.SymmDifference(constref aValue: TBoolVector): TBoolVector;
begin
  if System.Length(FBits) >= System.Length(aValue.FBits) then
    begin
      Result := Self;
      Result.DisjunctJoin(aValue);
    end
  else
    begin
      Result := aValue;
      Result.DisjunctJoin(Self);
    end;
end;

function TBoolVector.Equals(constref aValue: TBoolVector): Boolean;
var
  I: SizeInt;
begin
  if @Self = @aValue then
    exit(True);
  if System.Length(FBits) <> System.Length(aValue.FBits) then
    exit(False);
  for I := 0 to Pred(System.Length(FBits)) do
    if FBits[I] <> aValue.FBits[I] then
      exit(False);
  Result := True;
end;

function TBoolVector.PopCount: SizeInt;
var
  I: SizeInt;
begin
  I := 0;
  Result := 0;
  while I <= System.Length(FBits) - 4 do
    begin
      Result += SizeInt(PopCnt(FBits[I  ])) + SizeInt(PopCnt(FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2])) + SizeInt(PopCnt(FBits[I+3]));
      Inc(I, 4);
    end;
  case System.Length(FBits) - I of
    1:
      Result += SizeInt(PopCnt(FBits[I]));
    2:
      Result += SizeInt(PopCnt(FBits[I])) + SizeInt(PopCnt(FBits[I+1]));
    3:
      Result += SizeInt(PopCnt(FBits[I])) + SizeInt(PopCnt(FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2]));
  else
  end;
end;

{ TGVectorHelpUtil }

class procedure TGVectorHelpUtil.SwapItems(v: TVector; L, R: SizeInt);
begin
  v.CheckInIteration;
  THelper.SwapItems(v.FItems[0..Pred(v.ElemCount)], L, R);
end;

class procedure TGVectorHelpUtil.SwapItems(var v: TLiteVector; L, R: SizeInt);
begin
  THelper.SwapItems(v.FBuffer.FItems[0..Pred(v.Count)], L, R);
end;

class procedure TGVectorHelpUtil.Reverse(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Reverse(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGVectorHelpUtil.Reverse(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.Reverse(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class procedure TGVectorHelpUtil.RandomShuffle(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RandomShuffle(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGVectorHelpUtil.RandomShuffle(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.RandomShuffle(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGVectorHelpUtil.SequentSearch(v: TVector; const aValue: T; c: TEqualityCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGVectorHelpUtil.SequentSearch(constref v: TLiteVector; const aValue: T;
  c: TEqualityCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;


{ TGBaseVectorHelper }

class function TGBaseVectorHelper.SequentSearch(v: TVector; const aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.SequentSearch(constref v: TLiteVector; const aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.BinarySearch(v: TVector; const aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.BinarySearch(constref v: TLiteVector; const aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMin(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMin(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMax(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMax(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.GetMin(v: TVector): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGBaseVectorHelper.GetMin(constref v: TLiteVector): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGBaseVectorHelper.GetMax(v: TVector): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGBaseVectorHelper.GetMax(constref v: TLiteVector): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGBaseVectorHelper.FindMin(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMin(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMax(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMax(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.NthSmallest(v: TVector; N: SizeInt): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N);
end;

class function TGBaseVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N);
end;

class function TGBaseVectorHelper.NextPermutation2Asc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Asc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Desc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Desc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsNonDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsNonDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsStrictAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsStrictAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsNonAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsNonAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsStrictDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsStrictDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.Same(A, B: TVector): Boolean;
var
  c: SizeInt;
begin
  c := A.ElemCount;
  if B.ElemCount = c then
    Result := THelper.Same(A.FItems[0..Pred(c)], B.FItems[0..Pred(c)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.Same(constref A, B: TLiteVector): Boolean;
var
  c: SizeInt;
begin
  c := A.Count;
  if B.Count = c then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(c)], B.FBuffer.FItems[0..Pred(c)])
  else
    Result := False;
end;

class procedure TGBaseVectorHelper.QuickSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.QuickSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.IntroSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.IntroSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.PDQSort(v: TVector; o: TSortOrder);
begin
   v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.PDQSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.PDQSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.PDQSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.MergeSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.MergeSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class function TGBaseVectorHelper.SelectDistinct(v: TVector): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := nil;
end;

class function TGBaseVectorHelper.SelectDistinct(constref v: TLiteVector): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := nil;
end;

{ TGComparableVectorHelper }

class procedure TGComparableVectorHelper.Reverse(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Reverse(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGComparableVectorHelper.Reverse(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.Reverse(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class procedure TGComparableVectorHelper.RandomShuffle(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RandomShuffle(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGComparableVectorHelper.RandomShuffle(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.RandomShuffle(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.SequentSearch(v: TVector; const aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.SequentSearch(constref v: TLiteVector; const aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.BinarySearch(v: TVector; const aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.BinarySearch(constref v: TLiteVector; const aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMin(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMin(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMax(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMax(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.GetMin(v: TVector): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGComparableVectorHelper.GetMin(constref v: TLiteVector): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.GetMax(v: TVector): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGComparableVectorHelper.GetMax(constref v: TLiteVector): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.FindMin(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMin(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMax(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMax(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt;
  out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.NthSmallest(v: TVector; N: SizeInt): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N);
end;

class function TGComparableVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N);
end;

class function TGComparableVectorHelper.NextPermutation2Asc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Asc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Desc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Desc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsNonDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsNonDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsStrictAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsStrictAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsNonAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsNonAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsStrictDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsStrictDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.Same(A, B: TVector): Boolean;
var
  c: SizeInt;
begin
  c := A.ElemCount;
  if B.ElemCount = c then
    Result := THelper.Same(A.FItems[0..Pred(c)], B.FItems[0..Pred(c)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.Same(constref A, B: TLiteVector): Boolean;
var
  c: SizeInt;
begin
  c := A.Count;
  if B.Count = c then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(c)], B.FBuffer.FItems[0..Pred(c)])
  else
    Result := False;
end;

class procedure TGComparableVectorHelper.QuickSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.QuickSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.IntroSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.IntroSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.PDQSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.PDQSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.PDQSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.PDQSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.MergeSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.MergeSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class function TGComparableVectorHelper.SelectDistinct(v: TVector): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := nil;
end;

class function TGComparableVectorHelper.SelectDistinct(constref v: TLiteVector): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := nil;
end;

{ TGRegularVectorHelper }

class function TGRegularVectorHelper.SequentSearch(v: TVector; const aValue: T; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.SequentSearch(constref v: TLiteVector; const aValue: T;
  c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.BinarySearch(v: TVector; const aValue: T; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.BinarySearch(constref v: TLiteVector; const aValue: T;
  c: TLess): SizeInt;
begin

end;

class function TGRegularVectorHelper.IndexOfMin(v: TVector; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.IndexOfMax(v: TVector; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.IndexOfMax(constref v: TLiteVector; c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.GetMin(v: TVector; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGRegularVectorHelper.GetMin(constref v: TLiteVector; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGRegularVectorHelper.GetMax(v: TVector; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGRegularVectorHelper.GetMax(constref v: TLiteVector; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGRegularVectorHelper.FindMin(v: TVector; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMax(v: TVector; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGRegularVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGRegularVectorHelper.NextPermutation2Asc(v: TVector; c: TLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Desc(v: TVector; c: TLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsNonDescending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsNonDescending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsStrictAscending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsNonAscending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsNonAscending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsStrictDescending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.Same(A, B: TVector; c: TLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.Same(constref A, B: TLiteVector; c: TLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGRegularVectorHelper.QuickSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.QuickSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.IntroSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.IntroSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.PDQSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.PDQSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.PDQSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.PDQSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.MergeSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.MergeSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.Sort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.Sort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGRegularVectorHelper.SelectDistinct(v: TVector; c: TLess): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGRegularVectorHelper.SelectDistinct(constref v: TLiteVector; c: TLess): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

{ TGDelegatedVectorHelper }

class function TGDelegatedVectorHelper.SequentSearch(v: TVector; const aValue: T; c: TOnLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.SequentSearch(constref v: TLiteVector; const aValue: T;
  c: TOnLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.BinarySearch(v: TVector; const aValue: T; c: TOnLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.BinarySearch(constref v: TLiteVector; const aValue: T;
  c: TOnLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMin(v: TVector; c: TOnLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMin(constref v: TLiteVector; c: TOnLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMax(v: TVector; c: TOnLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMax(constref v: TLiteVector; c: TOnLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.GetMin(v: TVector; c: TOnLess): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGDelegatedVectorHelper.GetMin(constref v: TLiteVector; c: TOnLess): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGDelegatedVectorHelper.GetMax(v: TVector; c: TOnLess): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGDelegatedVectorHelper.GetMax(constref v: TLiteVector; c: TOnLess): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGDelegatedVectorHelper.FindMin(v: TVector; out aValue: T; c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMax(v: TVector; out aValue: T; c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T;
  c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T;
  c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TOnLess): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGDelegatedVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt;
  c: TOnLess): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGDelegatedVectorHelper.NextPermutation2Asc(v: TVector; c: TOnLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Desc(v: TVector; c: TOnLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsNonDescending(v: TVector; c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsNonDescending(constref v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsStrictAscending(v: TVector; c: TOnLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsStrictAscending(constref v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsNonAscending(v: TVector; c: TOnLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsNonAscending(constref v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsStrictDescending(v: TVector; c: TOnLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TOnLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.Same(A, B: TVector; c: TOnLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.Same(constref A, B: TLiteVector; c: TOnLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGDelegatedVectorHelper.QuickSort(v: TVector; c: TOnLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.QuickSort(var v: TLiteVector; c: TOnLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.IntroSort(v: TVector; c: TOnLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.IntroSort(var v: TLiteVector; c: TOnLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.PDQSort(v: TVector; c: TOnLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.PDQSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.PDQSort(var v: TLiteVector; c: TOnLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.PDQSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.MergeSort(v: TVector; c: TOnLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.MergeSort(var v: TLiteVector; c: TOnLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.Sort(v: TVector; c: TOnLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.Sort(var v: TLiteVector; c: TOnLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGDelegatedVectorHelper.SelectDistinct(v: TVector; c: TOnLess): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGDelegatedVectorHelper.SelectDistinct(constref v: TLiteVector;
  c: TOnLess): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

{ TGNestedVectorHelper }

class function TGNestedVectorHelper.SequentSearch(v: TVector; const aValue: T; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.SequentSearch(constref v: TLiteVector; const aValue: T;
  c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.BinarySearch(v: TVector; const aValue: T; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.BinarySearch(constref v: TLiteVector; const aValue: T;
  c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMin(v: TVector; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMin(constref v: TLiteVector; c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMax(v: TVector; c: TLess): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMax(constref v: TLiteVector; c: TLess): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.GetMin(v: TVector; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGNestedVectorHelper.GetMin(constref v: TLiteVector; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGNestedVectorHelper.GetMax(v: TVector; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGNestedVectorHelper.GetMax(constref v: TLiteVector; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGNestedVectorHelper.FindMin(v: TVector; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMax(v: TVector; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TLess): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGNestedVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt; c: TLess): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGNestedVectorHelper.NextPermutation2Asc(v: TVector; c: TLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Desc(v: TVector; c: TLess): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsNonDescending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsNonDescending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsStrictAscending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsStrictAscending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsNonAscending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsNonAscending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsStrictDescending(v: TVector; c: TLess): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TLess): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.Same(A, B: TVector; c: TLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.Same(constref A, B: TLiteVector; c: TLess): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGNestedVectorHelper.QuickSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.QuickSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.IntroSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.IntroSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.PDQSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.PDQSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.PDQSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.PDQSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.MergeSort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.MergeSort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.Sort(v: TVector; c: TLess; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.Sort(var v: TLiteVector; c: TLess; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGNestedVectorHelper.SelectDistinct(v: TVector; c: TLess): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGNestedVectorHelper.SelectDistinct(constref v: TLiteVector; c: TLess): TVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

{ TGOrdVectorHelper }

class procedure TGOrdVectorHelper.RadixSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RadixSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGOrdVectorHelper.RadixSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.RadixSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGOrdVectorHelper.RadixSort(v: TVector; var aBuf: TArray; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RadixSort(v.FItems[0..Pred(v.ElemCount)], aBuf, o);
end;

class procedure TGOrdVectorHelper.RadixSort(var v: TLiteVector; var aBuf: TArray; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.RadixSort(v.FBuffer.FItems[0..Pred(v.Count)], aBuf, o);
end;

class procedure TGOrdVectorHelper.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGOrdVectorHelper.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

{ TGRadixVectorSorter }

class procedure TGRadixVectorSorter.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGRadixVectorSorter.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGRadixVectorSorter.Sort(v: TVector; var aBuf: TArray; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], aBuf, o);
end;

class procedure TGRadixVectorSorter.Sort(var v: TLiteVector; var aBuf: TArray; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], aBuf, o);
end;

end.

