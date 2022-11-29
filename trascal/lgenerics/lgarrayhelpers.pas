{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic helper utils for arrays.                                        *
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
unit lgArrayHelpers;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses

  SysUtils, math, typinfo,
  lgUtils,
  {%H-}lgHelpers,
  lgStrConst;

type

  TSortOrder    = LGUtils.TSortOrder;
  TSizeIntArray = array of SizeInt;

  TSearchResult = record
    FoundIndex,
    InsertIndex: SizeInt;
    constructor Create(aFoundIndex, aInsertIndex: SizeInt);
  end;
  {.$DEFINE FPC_REQUIRES_PROPER_ALIGNMENT  :for test purpose only}

  { TGArrayHelpUtil }
  generic TGArrayHelpUtil<T> = class
  public
  type
    TItem             = T;
    PItem             = ^T;
    TArray            = specialize TGArray<T>;
    TOptional         = specialize TGOptional<T>;
    TEqualCompare     = specialize TGEqualCompare<T>;
    TOnEqualCompare   = specialize TGOnEqualCompare<T>;
    TNestEqualCompare = specialize TGNestEqualCompare<T>;
    TTest             = specialize TGTest<T>;
    TOnTest           = specialize TGOnTest<T>;
    TNestTest         = specialize TGNestTest<T>;
    TFold             = specialize TGFold<T, T>;
    TOnFold           = specialize TGOnFold<T, T>;
    TNestFold         = specialize TGNestFold<T, T>;

  protected
  const
    HEAP_INSERTION_SORT_CUTOFF  = 63;
    QUICK_INSERTION_SORT_CUTOFF = 47;
    MEDIAN_OF9_CUTOFF           = 511;
    DPQ_INSERTION_SORT_CUTOFF   = 47;
    INTROSORT_LOG_FACTOR        = 2;
    TRY_INSERT_SORT_LIMIT       = 64;
  type
    //to supress unnecessary refcounting
    TFake      = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};
    TFakeArray = array of TFake;
    TSortSplit = record
      Left,
      Right: SizeInt;
    end;

    TMergeSortBase = object
    protected
    const
      MERGE_STACK_SIZE  = 64;
      MERGE_BUFFER_SIZE = 512;
      MIN_MERGE_POW     = 5;
      MIN_MERGE_LEN     = SizeInt(1) shl MIN_MERGE_POW;

    type
      TRun      = record
        Base, Count: SizeInt;
      end;
      PRun      = ^TRun;
      TRunArray = array of TRun;
    var
      FBuffer: array[0..Pred(MERGE_BUFFER_SIZE)] of TFake;
      FInitStack: array[0..Pred(MERGE_STACK_SIZE)] of TRun;
      FData: PItem; // pointer to data array
      FDynBuffer: TFakeArray;
      FDynStack: TRunArray;
      FStack: PRun;
      FStackCount,
      FStackSize: SizeInt;
      procedure PushRun(aBase, aCount: SizeInt);
      function  EnsureBufferSize(aSize: SizeInt): PItem;
      procedure Init(A: PItem);
      class function  MinRunLen(aTotalSize: SizeInt): SizeInt; static;
    end;

    TBlockQSortBase = object
    public
    type
      TPart = specialize TGTuple2<PItem, Boolean>;
    protected
    const
      BLOCK_SIZE                   = 128;
      CACHE_LINE_SIZE              = 64;
      PARTIAL_INSERTION_SORT_LIMIT = 12;
      NINTHER_THRESHOLD            = 128;
    var
      FOffsetsLStorage, FOffsetsRStorage: array[0..Pred(BLOCK_SIZE + CACHE_LINE_SIZE)] of Byte;
      class procedure SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
                                  aNum: SizeInt; aUseSwaps: Boolean); static;
    end;

    TReverseEnumerator = record
    private
      FCurrent,
      FFirst: PItem;
      function GetCurrent: T; inline;
    public
      constructor Create(aFirst, aLast: PItem);
      function GetEnumerator: TReverseEnumerator;inline;
      function MoveNext: Boolean; inline;
      property Current: T read GetCurrent;
    end;

    class procedure CopyItems(aSrc, aDst: PItem; aCount: SizeInt); static;
    class procedure DoReverse(p: PItem; R: SizeInt); static;
    class procedure PtrSwap(var L, R: Pointer); static; inline;
  public
    class procedure Swap(var L, R: T); static; inline;
  { swaps the elements of A with the indices L and R;
    raises EArgumentException if L or R is out of bounds }
    class procedure SwapItems(var A: array of T; L, R: SizeInt); static;
    class function  CreateCopy(const A: array of T): TArray; static;
    class function  CreateReverseCopy(const A: array of T): TArray; static;
    class function  CreateMerge(const L, R: array of T): TArray; static;
    class function  CreateRandomShuffle(const A: array of T): TArray; static;
    class function  CreateAndFill(const aValue: T; aSize: SizeInt): TArray; static;
    class procedure Fill(var A: array of T; const aValue: T); static;
  { returns resized array }
    class function  Resize(var A: TArray; aNewSize: SizeInt): TArray; static; inline;
    class function  Append(var A: TArray; const aValue: T): SizeInt; static;
  { copies with replacement Min(Length(aSource), Length(aTarget)) elements from aSource to
    aTarget; returns the number of copied elements }
    class function  CopyFrom(const aSource: array of T; var aTarget: array of T): SizeInt; static;
  { if aSrc <> aDst appends aSrc to aDst, sets aSrc to nil and returns count of merged elements,
    otherwise returns 0}
    class function  Merge(var aDst, aSrc: TArray): SizeInt; static;
  { concatenates the elements of all components of array A into a single array }
    class function  Concat(const A: array of TArray): TArray; static;
  { returns array of elements of A starting at aIndex(0-based) to High(A);
    length of A becomes aIndex;
    if A = nil or aIndex > High(A), then Result is empty }
    class function  Split(var A: TArray; aIndex: SizeInt): TArray; static;
  { extracts array of aCount elements of A starting at aIndex(0-based);
    if aIndex > High(A) or aCount < 1, then Result is empty;
    if aCount > length A then Result is truncated }
    class function  Extract(var A: TArray; aIndex, aCount: SizeInt): TArray; static;
    class procedure Reverse(var A: array of T); static;
    class function  ReverseOrder(const A: array of T): TReverseEnumerator; static;
  { cyclic shift of array elements by aDist positions to the left;
    the case if Abs(aDist) > Length(A) is ignored }
    class procedure RotateLeft(var A: array of T; aDist: SizeInt); static;
  { cyclic shift of array elements by aDist positions to the right;
    the case if Abs(aDist) > Length(A) is ignored }
    class procedure RotateRight(var A: array of T; aDist: SizeInt); static;
    class procedure RandomShuffle(var A: array of T); static;
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T; c: TEqualCompare): SizeInt;
                    static;
    class function  SequentSearch(const A: array of T; const aValue: T; c: TOnEqualCompare): SizeInt;
                    static;
    class function  SequentSearch(const A: array of T; const aValue: T; c: TNestEqualCompare): SizeInt;
                    static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T; c: TEqualCompare): Boolean; static;
    class function  Same(const A, B: array of T; c: TOnEqualCompare): Boolean; static;
    class function  Same(const A, B: array of T; c: TNestEqualCompare): Boolean; static;
    class function  Select(const A: array of T; aTest: TTest): TArray; static;
    class function  Select(const A: array of T; aTest: TOnTest): TArray; static;
    class function  Select(const A: array of T; aTest: TNestTest): TArray; static;
    class procedure RemoveIf(var A: TArray; aTest: TTest); static;
    class procedure RemoveIf(var A: TArray; aTest: TOnTest); static;
    class procedure RemoveIf(var A: TArray; aTest: TNestTest); static;
  { left-associative linear fold }
    class function  FoldL(const A: array of T; aFold: TFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldL(const A: array of T; aFold: TFold): TOptional; static;
    class function  FoldL(const A: array of T; aFold: TOnFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldL(const A: array of T; aFold: TOnFold): TOptional; static;
    class function  FoldL(const A: array of T; aFold: TNestFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldL(const A: array of T; aFold: TNestFold): TOptional; static;
  { right-associative linear fold }
    class function  FoldR(const A: array of T; aFold: TFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldR(const A: array of T; aFold: TFold): TOptional; static;
    class function  FoldR(const A: array of T; aFold: TOnFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldR(const A: array of T; aFold: TOnFold): TOptional; static;
    class function  FoldR(const A: array of T; aFold: TNestFold; const aInitVal: T): T; static;
  { result is assigned only if A is not empty; uses Default(T) as the initial value }
    class function  FoldR(const A: array of T; aFold: TNestFold): TOptional; static;
  end;

  { TGIndexedHelpUtil
      type TIndexed must provide:
        method/property Count: SizeInt - number of items contained;
        property UncMutable[aIndex: SizeInt]: PItem - indexed access to items }
  generic TGIndexedHelpUtil<T, TIndexed> = class
  protected
  type
    TUtil = class(specialize TGArrayHelpUtil<T>);
  public
  type
    TItem             = TUtil.TItem;
    PItem             = TUtil.PItem;
    TEqualCompare     = TUtil.TEqualCompare;
    TOnEqualCompare   = TUtil.TOnEqualCompare;
    TNestEqualCompare = TUtil.TNestEqualCompare;
    TArray            = TUtil.TArray;
  protected
  type
    TFake = TUtil.TFake;
    class procedure Swap(L, R: PItem); static; inline;
    class procedure DoReverse(var e: TIndexed; L, R: SizeInt); static; inline;
  public
    class function  CreateCopy(const aEntity: TIndexed; aFrom, aCount: SizeInt): TArray; static;
    class procedure Reverse(var aEntity: TIndexed); static;
    class procedure Reverse(var aEntity: TIndexed; aFirst, aLast: SizeInt); static;
    class procedure RandomShuffle(var aEntity: TIndexed); static;
    class function  SequentSearch(const aEntity: TIndexed; const aValue: T;
                    c: TEqualCompare): SizeInt; static;
    class function  SequentSearch(const aEntity: TIndexed; const aValue: T;
                    c: TOnEqualCompare): SizeInt; static;
    class function  SequentSearch(const aEntity: TIndexed; const aValue: T;
                    c: TNestEqualCompare): SizeInt; static;
    class function  Same(const e1, e2: TIndexed; c: TEqualCompare): Boolean; static;
    class function  Same(const e1, e2: TIndexed; c: TOnEqualCompare): Boolean; static;
    class function  Same(const e1, e2: TIndexed; c: TNestEqualCompare): Boolean; static;
  end;

  { TGBaseArrayHelper
      functor TCmpRel(comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean }
  generic TGBaseArrayHelper<T, TCmpRel> = class(specialize TGArrayHelpUtil<T>)
  protected
  type

    TMergeSort = object(TMergeSortBase)
    private
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      procedure MergeLoA(From, CountLo, CountHi: SizeInt);
      procedure MergeLoD(From, CountLo, CountHi: SizeInt);
      procedure MergeHiA(From, CountLo, CountHi: SizeInt);
      procedure MergeHiD(From, CountLo, CountHi: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt); static;
      class function  CountRunAsc(A: PItem; R: SizeInt): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt); static;
      class procedure SortDesc(A: PItem; R: SizeInt); static;
    end;

    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, C: PItem); static; inline;
      function  PartitionRight(aStart, aFinish: PItem): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean);
      class function  PartialInsertionSort(aStart, aFinish: PItem): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem): PItem; static;
    public
      class procedure PDQSort(aStart, aFinish: PItem); static;
    end;

    class function  TryInsertSortA(A: PItem; L, R: SizeInt): SizeInt; static;
    class function  TryInsertSortD(A: PItem; L, R: SizeInt): SizeInt; static;
    class function  CountRun(A: PItem; R: SizeInt; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(A: PItem; R: SizeInt); static;
    class procedure UnguardInsertionSort(A: PItem; R: SizeInt); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult; static;
    class procedure DoHeapSort(A: PItem; R: SizeInt); static;
    class function  QSplitR(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoQSort(A: PItem; R: SizeInt; aLeftmost: Boolean); static;
    class function  MedianOf3(p1, p2, p3: PItem): PItem; static; inline;
    class function  QSplitMo9(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoIntroSort(A: PItem; R, Ttl: SizeInt; aLeftmost: Boolean); static;
    class function  DPQSplit(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoDPQSort(A: PItem; R: SizeInt; aLeftmost: Boolean); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(A: PItem; R, N: SizeInt): T; static;
  public
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T): TSearchResult; static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A is nonempty }
    class function  GetMin(const A: array of T): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T): TOptional; static;
  { returns True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T): Boolean; static;
  { returns True and greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax, if A is nonempty,
    False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var A: array of T; N: SizeInt): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const A: array of T; N: SizeInt): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T): Boolean; static;
  { returns the number of inversions in A, sorts an array }
    class function  InversionCount(var A: array of T): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T): Boolean; static;
  { returns an array of indices of some  Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort inspired by Java Timsort, requires O(N) auxiliary memory }
    class procedure MergeSort(var A: array of T; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort}
    class procedure Sort(var A: array of T; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T): TArray; static;
  end;

  { TGArrayHelper assumes that type T implements TCmpRel }
  generic TGArrayHelper<T> = class(specialize TGBaseArrayHelper<T, T>);

  { TGBaseIndexedHelper
      type TIndexed must provide:
        method/property Count: SizeInt - number of items contained;
        property UncMutable[aIndex: SizeInt]: PItem - indexed access to items;
      functor TCmpRel(comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseIndexedHelper<T, TIndexed, TCmpRel> = class(specialize TGIndexedHelpUtil<T, TIndexed>)
  type
    TOptional = TUtil.TOptional;
  protected
  type
    TSortSplit = TUtil.TSortSplit;

    class function  BiSearchLeftA(const e: TIndexed; L, R: SizeInt; const aValue: T): SizeInt;
                    static;
    class function  BiSearchLeftD(const e: TIndexed; L, R: SizeInt; const aValue: T): SizeInt;
                    static;
    class function  BiSearchRightA(const e: TIndexed; L, R: SizeInt; const aValue: T): SizeInt;
                    static;
    class function  BiSearchRightD(const e: TIndexed; L, R: SizeInt; const aValue: T): SizeInt;
                    static;
    class function  DoBinSearch(const e: TIndexed; L, R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearchPos(const e: TIndexed; L, R: SizeInt; const aValue: T): TSearchResult;
                    static;
    class function  CountRun(var e: TIndexed; L, R: SizeInt; o: TSortOrder): SizeInt;
    class procedure InsertionSort(var e: TIndexed; L, R: SizeInt); static;
    class procedure DoHeapSort(var e: TIndexed; L, R: SizeInt); static;
    class function  MedianOf3(p1, p2, p3: PItem): PItem; static; inline;
    class function  QSplitMo9(var e: TIndexed; L, R: SizeInt): TSortSplit; static;
    class procedure DoIntroSort(var e: TIndexed; L, R, Ttl: SizeInt); static;
  public
    class function  SequentSearch(const aEntity: TIndexed; const aValue: T): SizeInt; static;
    class function  BinarySearch(const aEntity: TIndexed; const aValue: T): SizeInt; static;
    class function  BinarySearchPos(const aEntity: TIndexed; const aValue: T): TSearchResult; static;
    class function  IndexOfMin(const aEntity: TIndexed): SizeInt; static;
    class function  IndexOfMax(const aEntity: TIndexed): SizeInt; static;
    class function  GetMin(const aEntity: TIndexed): TOptional; static;
    class function  GetMax(const aEntity: TIndexed): TOptional; static;
    class function  FindMin(const aEntity: TIndexed; out aValue: T): Boolean; static;
    class function  FindMax(const aEntity: TIndexed; out aValue: T): Boolean; static;
    class function  FindMinMax(const aEntity: TIndexed; out aMin, aMax: T): Boolean; static;
    class function  FindNthSmallest(const aEntity: TIndexed; N: SizeInt; out aValue: T): Boolean; static;
    class function  NthSmallest(const aEntity: TIndexed; N: SizeInt): TOptional; static;
    class function  NextPermutation2Asc(var aEntity: TIndexed): Boolean; static;
    class function  NextPermutation2Desc(var aEntity: TIndexed): Boolean; static;
    class function  InversionCount(const aEntity: TIndexed): Int64; static;
    class function  IsNonDescending(const aEntity: TIndexed): Boolean; static;
    class function  IsStrictAscending(const aEntity: TIndexed): Boolean; static;
    class function  IsNonAscending(const aEntity: TIndexed): Boolean; static;
    class function  IsStrictDescending(const aEntity: TIndexed): Boolean; static;
  { returns an array of indices of the Longest Increasing Subsequence of aEntity,
    if any, otherwise returns an empty array }
    class function  Lis(const aEntity: TIndexed): TSizeIntArray; static;
    class function  Same(const e1, e2: TIndexed): Boolean; static;
    class procedure Sort(var aEntity: TIndexed; o: TSortOrder = soAsc); static;
    class procedure Sort(var aEntity: TIndexed; aFirst, aLast: SizeInt; o: TSortOrder = soAsc); static;
  { copies only distinct values from aEntity }
    class function  SelectDistinct(const aEntity: TIndexed): TArray; static;
  end;

  { TGIndexedHelper assumes that type T implements TCmpRel }
  generic TGIndexedHelper<T, TIndexed> = class(specialize TGBaseIndexedHelper<T, TIndexed, T>);

  {TGComparableArrayHelper assumes that type T defines comparison operator < }
  generic TGComparableArrayHelper<T> = class(specialize TGArrayHelpUtil<T>)
  public
    class function ValEqual(const L, R: T): Boolean; static; inline;
    class function ValNotEqual(const L, R: T): Boolean; static; inline;
  protected
  type
    TMergeSort = object(TMergeSortBase)
    private
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      procedure MergeLoA(From, CountLo, CountHi: SizeInt);
      procedure MergeLoD(From, CountLo, CountHi: SizeInt);
      procedure MergeHiA(From, CountLo, CountHi: SizeInt);
      procedure MergeHiD(From, CountLo, CountHi: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt); static;
      class function  CountRunAsc(A: PItem; R: SizeInt): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt); static;
      class procedure SortDesc(A: PItem; R: SizeInt); static;
    end;

    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, C: PItem); static; inline;
      function  PartitionRight(aStart, aFinish: PItem): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean);
      class function  PartialInsertionSort(aStart, aFinish: PItem): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem): PItem; static;
    public
      class procedure PDQSort(aStart, aFinish: PItem); static;
    end;

    class function  TryInsertSortA(A: PItem; L, R: SizeInt): SizeInt; static;
    class function  TryInsertSortD(A: PItem; L, R: SizeInt): SizeInt; static;
    class function  CountRun(A: PItem; R: SizeInt; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(A: PItem; R: SizeInt); static;
    class procedure UnguardInsertionSort(A: PItem; R: SizeInt); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult; static;
    class procedure DoHeapSort(A: PItem; R: SizeInt); static;
    class function  QSplitR(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoQSort(A: PItem; R: SizeInt; aLeftmost: Boolean); static;
    class function  MedianOf3(p1, p2, p3: PItem): PItem; static; inline;
    class function  QSplitMo9(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoIntroSort(A: PItem; R, Ttl: SizeInt; aLeftmost: Boolean); static;
    class function  DPQSplit(A: PItem; R: SizeInt): TSortSplit; static;
    class procedure DoDPQSort(A: PItem; R: SizeInt; aLeftmost: Boolean); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(A: PItem; R, N: SizeInt): T; static;
  public
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T): TSearchResult; static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A is nonempty }
    class function  GetMin(const A: array of T): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T): TOptional; static;
  { retursn True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T): Boolean; static;
  { returns True and  greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax,
    if A is nonempty, False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var A: array of T; N: SizeInt): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const A: array of T; N: SizeInt): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T): Boolean; static;
  { returns the number of inversions in A, sorts an array }
    class function  InversionCount(var A: array of T): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T): Boolean; static;
  { returns an array of indices of some Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort inspired by Java Timsort, requires O(N) auxiliary memory }
    class procedure MergeSort(var A: array of T; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort }
    class procedure Sort(var A: array of T; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T): TArray; static;
  end;

  { TGRegularArrayHelper: with regular comparator}
  generic TGRegularArrayHelper<T> = class(specialize TGArrayHelpUtil<T>)
  public
  type
    TLess = specialize TGLessCompare<T>;

  protected
  type
    TMergeSort = object(TMergeSortBase)
    private
      FLess: TLess;
      procedure Init(A: PItem; c: TLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      procedure MergeLoA(From, CountLo, CountHi: SizeInt);
      procedure MergeLoD(From, CountLo, CountHi: SizeInt);
      procedure MergeHiA(From, CountLo, CountHi: SizeInt);
      procedure MergeHiD(From, CountLo, CountHi: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TLess); static;
    end;

    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, D: PItem; c: TLess); static; inline;
      function  PartitionRight(aStart, aFinish: PItem; c: TLess): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean; c: TLess);
      class function  PartialInsertionSort(aStart, aFinish: PItem; c: TLess): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem; c: TLess): PItem; static;
    public
      class procedure PDQSort(aStart, aFinish: PItem; c: TLess); static;
    end;

    class function  TryInsertSortA(A: PItem; L, R: SizeInt; c: TLess): SizeInt; static;
    class function  TryInsertSortD(A: PItem; L, R: SizeInt; c: TLess): SizeInt; static;
    class function  CountRun(A: PItem; R: SizeInt; c: TLess; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(A: PItem; R: SizeInt; c: TLess); static;
    class procedure UnguardInsertionSort(A: PItem; R: SizeInt; c: TLess); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T; c: TLess): SizeInt; static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T; c: TLess): SizeInt; static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T; c: TLess): SizeInt; static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T; c: TLess): SizeInt; static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T; c: TLess): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T; c: TLess): TSearchResult;
                    static;
    class procedure DoHeapSort(A: PItem; R: SizeInt; c: TLess); static;
    class function  QSplitR(A: PItem; R: SizeInt; c: TLess): TSortSplit; static;
    class procedure DoQSort(A: PItem; R: SizeInt; c: TLess; aLeftmost: Boolean); static;
    class function  MedianOf3(p1, p2, p3: PItem; c: TLess): PItem; static; inline;
    class function  QSplitMo9(A: PItem; R: SizeInt; c: TLess): TSortSplit; static;
    class procedure DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TLess; aLeftmost: Boolean); static;
    class function  DPQSplit(A: PItem; R: SizeInt; c: TLess): TSortSplit; static;
    class procedure DoDPQSort(A: PItem; R: SizeInt; c: TLess; aLeftmost: Boolean); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(A: PItem; R, N: SizeInt; c: TLess): T; static;
  public
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T; c: TLess): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T; c: TLess): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T; c: TLess): TSearchResult;
                    static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T; c: TLess): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T; c: TLess): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A <> nil }
    class function  GetMin(const A: array of T; c: TLess): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T; c: TLess): TOptional; static;
  { returns True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T; c: TLess): Boolean; static;
  { returns True and  greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T; c: TLess): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax,
    if A is nonempty, False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T; c: TLess): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T; c: TLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var A: array of T; N: SizeInt; c: TLess): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T; c: TLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const A: array of T; N: SizeInt; c: TLess): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T; c: TLess): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T; c: TLess): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T; c: TLess): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T; c: TLess): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T; c: TLess): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T; c: TLess): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T; c: TLess): Boolean; static;
  { returns the number of inversions in A, sorts an array }
    class function  InversionCount(var A: array of T; c: TLess): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T; c: TLess): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T; c: TLess): Boolean; static;
  { returns an array of indices of some Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T; c: TLess): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T; c: TLess): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T; c: TLess): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort inspired by Java Timsort, requires O(N) auxiliary memory }
    class procedure MergeSort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort }
    class procedure Sort(var A: array of T; c: TLess; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; c: TLess; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T; c: TLess): TArray; static;
  end;

  { TGDelegatedArrayHelper: with delegated comparator}
  generic TGDelegatedArrayHelper<T> = class(specialize TGArrayHelpUtil<T>)
  public
  type
    TOnLess = specialize TGOnLessCompare<T>;

  protected
  type
    TMergeSort = object(TMergeSortBase)
    protected
      FLess: TOnLess;
      procedure Init(A: PItem; c: TOnLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      procedure MergeLoA(From, CountLo, CountHi: SizeInt);
      procedure MergeLoD(From, CountLo, CountHi: SizeInt);
      procedure MergeHiA(From, CountLo, CountHi: SizeInt);
      procedure MergeHiD(From, CountLo, CountHi: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TOnLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TOnLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TOnLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TOnLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TOnLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TOnLess); static;
    end;

    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, D: PItem; c: TOnLess); static; inline;
      function  PartitionRight(aStart, aFinish: PItem; c: TOnLess): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean; c: TOnLess);
      class function  PartialInsertionSort(aStart, aFinish: PItem; c: TOnLess): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem; c: TOnLess): PItem; static;
    public
      class procedure PDQSort(aStart, aFinish: PItem; c: TOnLess); static;
    end;

    class function  TryInsertSortA(A: PItem; L, R: SizeInt; c: TOnLess): SizeInt; static;
    class function  TryInsertSortD(A: PItem; L, R: SizeInt; c: TOnLess): SizeInt; static;
    class function  CountRun(A: PItem; R: SizeInt; c: TOnLess; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(A: PItem; R: SizeInt; c: TOnLess); static;
    class procedure UnguardInsertionSort(A: PItem; R: SizeInt; c: TOnLess); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): SizeInt; static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): SizeInt; static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): SizeInt; static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): SizeInt; static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T; c: TOnLess): TSearchResult;
                    static;
    class procedure DoHeapSort(A: PItem; R: SizeInt; c: TOnLess); static;
    class function  QSplitR(A: PItem; R: SizeInt; c: TOnLess): TSortSplit; static;
    class procedure DoQSort(A: PItem; R: SizeInt; c: TOnLess; aLeftmost: Boolean); static;
    class function  MedianOf3(p1, p2, p3: PItem; c: TOnLess): PItem; static; inline;
    class function  QSplitMo9(A: PItem; R: SizeInt; c: TOnLess): TSortSplit; static;
    class procedure DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TOnLess; aLeftmost: Boolean); static;
    class function  DPQSplit(A: PItem; R: SizeInt; c: TOnLess): TSortSplit; static;
    class procedure DoDPQSort(A: PItem; R: SizeInt; c: TOnLess; aLeftmost: Boolean); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(A: PItem; R, N: SizeInt; c: TOnLess): T; static;
  public
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T; c: TOnLess): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T; c: TOnLess): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T; c: TOnLess): TSearchResult; static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T; c: TOnLess): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T; c: TOnLess): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A is nonempty }
    class function  GetMin(const A: array of T; c: TOnLess): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T; c: TOnLess): TOptional; static;
  { returns True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T; c: TOnLess): Boolean; static;
  { returns True and  greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T; c: TOnLess): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax,
    if A is nonempty, False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T; c: TOnLess): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T; c: TOnLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var A: array of T; N: SizeInt; c: TOnLess): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const A: array of T;N: SizeInt; out aValue: T; c: TOnLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const A: array of T; N: SizeInt; c: TOnLess): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T; c: TOnLess): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T; c: TOnLess): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T; c: TOnLess): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T; c: TOnLess): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T; c: TOnLess): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T; c: TOnLess): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T; c: TOnLess): Boolean; static;
  { returns the number of inversions in A, sorts an array }
    class function  InversionCount(var A: array of T; c: TOnLess): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T; c: TOnLess): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T; c: TOnLess): Boolean; static;
  { returns an array of indices of some Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T; c: TOnLess): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T; c: TOnLess): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T; c: TOnLess): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort inspired by Java Timsort, requires O(N) auxiliary memory }
    class procedure MergeSort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort }
    class procedure Sort(var A: array of T; c: TOnLess; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; c: TOnLess; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T; c: TOnLess): TArray; static;
  end;

  { TGNestedArrayHelper: with nested comparator}
  generic TGNestedArrayHelper<T> = class(specialize TGArrayHelpUtil<T>)
  public
  type
    TNestLess = specialize TGNestLessCompare<T>;

  protected
  type
    TMergeSort = object(TMergeSortBase)
    protected
      FLess: TNestLess;
      procedure Init(A: PItem; c: TNestLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      procedure MergeLoA(From, CountLo, CountHi: SizeInt);
      procedure MergeLoD(From, CountLo, CountHi: SizeInt);
      procedure MergeHiA(From, CountLo, CountHi: SizeInt);
      procedure MergeHiD(From, CountLo, CountHi: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TNestLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TNestLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TNestLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TNestLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TNestLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TNestLess); static;
    end;

    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, D: PItem; c: TNestLess); static;{$ifndef CPU86}inline;{$endif}//todo: ???
      function  PartitionRight(aStart, aFinish: PItem; c: TNestLess): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean; c: TNestLess);
      class function  PartialInsertionSort(aStart, aFinish: PItem; c: TNestLess): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem; c: TNestLess): PItem; static;
    public
      class procedure PDQSort(aStart, aFinish: PItem; c: TNestLess); static;
    end;

    class function  TryInsertSortA(A: PItem; L, R: SizeInt; c: TNestLess): SizeInt; static;
    class function  TryInsertSortD(A: PItem; L, R: SizeInt; c: TNestLess): SizeInt; static;
    class function  CountRun(A: PItem; R: SizeInt; c: TNestLess; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(A: PItem; R: SizeInt; c: TNestLess); static;
    class procedure UnguardInsertionSort(A: PItem; R: SizeInt; c: TNestLess); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): SizeInt;
                    static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): SizeInt;
                    static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): SizeInt;
                    static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): SizeInt;
                    static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T; c: TNestLess): TSearchResult;
                    static;
    class procedure DoHeapSort(A: PItem; R: SizeInt; c: TNestLess); static;
    class function  QSplitR(A: PItem; R: SizeInt; c: TNestLess): TSortSplit; static;
    class procedure DoQSort(A: PItem; R: SizeInt; c: TNestLess; aLeftmost: Boolean); static;
    class function  MedianOf3(p1, p2, p3: PItem; c: TNestLess): PItem; static; inline;
    class function  QSplitMo9(A: PItem; R: SizeInt; c: TNestLess): TSortSplit; static;
    class procedure DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TNestLess; aLeftmost: Boolean); static;
    class function  DPQSplit(A: PItem; R: SizeInt; c: TNestLess): TSortSplit; static;
    class procedure DoDPQSort(A: PItem; R: SizeInt; c: TNestLess; aLeftmost: Boolean); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(A: PItem; R, N: SizeInt; c: TNestLess): T; static;
  public
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T; c: TNestLess): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T; c: TNestLess): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T; c: TNestLess): TSearchResult;
                    static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T; c: TNestLess): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T; c: TNestLess): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A is nonempty }
    class function  GetMin(const A: array of T; c: TNestLess): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T; c: TNestLess): TOptional; static;
  { returns True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T; c: TNestLess): Boolean; static;
  { returns True and  greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T; c: TNestLess): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax,
    if A is nonempty, False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T; c: TNestLess): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T; c: TNestLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var A: array of T; N: SizeInt; c: TNestLess): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const A: array of T;N: SizeInt; out aValue: T; c: TNestLess): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const A: array of T; N: SizeInt; c: TNestLess): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T; c: TNestLess): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T; c: TNestLess): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T; c: TNestLess): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T; c: TNestLess): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T; c: TNestLess): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T; c: TNestLess): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T; c: TNestLess): Boolean; static;
  { returns the number of inversions in A, sorts array }
    class function  InversionCount(var A: array of T; c: TNestLess): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T; c: TNestLess): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T; c: TNestLess): Boolean; static;
  { returns an array of indices of some Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T; c: TNestLess): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T; c: TNestLess): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T; c: TNestLess): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
  { stable, adaptive mergesort inspired by Java Timsort, requires O(N) auxiliary memory }
    class procedure MergeSort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort }
    class procedure Sort(var A: array of T; c: TNestLess; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; c: TNestLess; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T; c: TNestLess): TArray; static;
  end;

  { TGSimpleArrayHelper: for simple types only }
  generic TGSimpleArrayHelper<T> = class(specialize TGArrayHelpUtil<T>)
  protected
  const
    RADIX_CUTOFF   = 255;
    RADIX_BUF_SIZE = 1024;
  type
    TBlockQSort = object(TBlockQSortBase)
    private
      class procedure Sort3(A, B, C: PItem); static; inline;
      function  PartitionRight(aStart, aFinish: PItem): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean);
      class function  PartialInsertionSort(aStart, aFinish: PItem): Boolean; static;
      class function  PartitionLeft(aStart, aFinish: PItem): PItem; static;
      class procedure SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
                                  aNum: SizeInt; aUseSwaps: Boolean); static;
    public
      class procedure PDQSort(aStart, aFinish: PItem); static;
    end;

    class function  TryInsertSortA(var A: array of T; L, R: SizeInt): SizeInt; static;
    class function  TryInsertSortD(var A: array of T; L, R: SizeInt): SizeInt; static;
    class function  CountRun(var A: array of T; L, R: SizeInt; o: TSortOrder): SizeInt; static;
    class procedure InsertionSort(var A: array of T; L, R: SizeInt); static;
    class procedure UnguardInsertionSort(var A: array of T; L, R: SizeInt); static;
    class function  BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt; static;
    class function  DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult; static;
    class procedure DoHeapSort(A: PItem; R: SizeInt); static;
    class function  QSplitR(var A: array of T; L, R: SizeInt): TSortSplit; static;
    class procedure DoQSort(var A: array of T; L, R: SizeInt); static;
    class function  MedianOf3(p1, p2, p3: PItem): PItem; static; inline;
    class function  GetMo9Pivot(const A: array of T; L, R: SizeInt): T; static;
    class function  QSplitMo9(var A: array of T; L, R: SizeInt): TSortSplit; static;
    class procedure DoIntroSort(var A: array of T; L, R, Ttl: SizeInt); static;
    class function  DPQSplit(var A: array of T; L, R: SizeInt): TSortSplit; static;
    class procedure DoDPQSort(var A: array of T; L, R: SizeInt); static;
    class procedure DoSwap(p: PItem; L, R: SizeInt); static; inline;
    class procedure DoReverse(var A: array of T; L, R: SizeInt); static;
  { QuickSelect with random pivot selection, does not checks indices }
    class function  QSelectR(var A: array of T; N: SizeInt): T; static;
  public
    class procedure Swap(var L, R: T); static; inline;
    class procedure Reverse(var A: array of T); static;
  { cyclic shift of array elements by aDist positions to the left;
    the case if Abs(aDist) > Length(A) is ignored }
    class procedure RotateLeft(var A: array of T; aDist: SizeInt); static;
  { cyclic shift of array elements by aDist positions to the right;
    the case if Abs(aDist) > Length(A) is ignored }
    class procedure RotateRight(var A: array of T; aDist: SizeInt); static;
  { returns 0-based leftmost position of aValue in array A, -1 if not found }
    class function  SequentSearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based leftmost position of aValue in SORTED array A, -1 if not found }
    class function  BinarySearch(const A: array of T; const aValue: T): SizeInt; static;
  { returns 0-based rightmost position of aValue in SORTED array A in Result.FoundIndex(-1 if not found);
    returns position for insertion in Result.InsertIndex }
    class function  BinarySearchPos(const A: array of T; const aValue: T): TSearchResult; static;
  { returns 0-based position of minimal value in A, -1 if A is empty }
    class function  IndexOfMin(const A: array of T): SizeInt; static;
  { returns 0-based position of maximal value in A, -1 if A is empty }
    class function  IndexOfMax(const A: array of T): SizeInt; static;
  { returns smallest element of A in TOptional.Value if A is nonempty }
    class function  GetMin(const A: array of T): TOptional; static;
  { returns greatest element of A in TOptional.Value if A is nonempty }
    class function  GetMax(const A: array of T): TOptional; static;
  { returns True and smallest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMin(const A: array of T; out aValue: T): Boolean; static;
  { returns True and  greatest element of A in aValue if A is nonempty, False otherwise }
    class function  FindMax(const A: array of T; out aValue: T): Boolean; static;
  { returns True, smallest element of A in aMin and greatest element of A in aMax,
    if A is nonempty, False otherwise }
    class function  FindMinMax(const A: array of T; out aMin, aMax: T): Boolean; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    destructive: changes the order of elements in A }
    class function  FindNthSmallest(var  A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is destructive: changes the order of elements in A }
    class function  NthSmallest(var  A: array of T; N: SizeInt): TOptional; static;
  { returns True and A's Nth order statistic(0-based) in aValue if A is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  FindNthSmallestND(const  A: array of T; N: SizeInt; out aValue: T): Boolean; static;
  { returns A's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(A) then N sets to High(A);
    is nondestructive: creates a temp copy of A }
    class function  NthSmallestND(const  A: array of T; N: SizeInt): TOptional; static;
  { returns True if permutation towards nondescending state of A has done, False otherwise }
    class function  NextPermutation2Asc(var A: array of T): Boolean; static;
  { returns True if permutation towards nonascending state of A has done, False otherwise }
    class function  NextPermutation2Desc(var A: array of T): Boolean; static;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function  IsPermutation(const A, aPerm: array of T): Boolean; static;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(const A: array of T): Boolean; static;
  { note: an empty array or single element array is never strict descending }
    class function  IsStrictDescending(const A: array of T): Boolean; static;
  { returns the number of inversions in A, sorts array }
    class function  InversionCount(var A: array of T): Int64; static;
  { returns the number of inversions in A, nondestructive }
    class function  InversionCountND(const A: array of T): Int64; static;
  { returns True if aSeq is a subsequence of A, False otherwise;
    the empty sequence is a subsequence of any other sequence }
    class function  IsSubSequence(const A, aSeq: array of T): Boolean; static;
  { returns an array of indices of some Longest Increasing Subsequence of A,
    if any, otherwise returns nil; uses O(N*Log(N)) algorithm }
    class function  LisI(const A: array of T): TSizeIntArray; static;
  { returns some Longest Increasing Subsequence of A, if any, otherwise returns nil }
    class function  Lis(const A: array of T): TArray; static;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(const A, B: array of T): Boolean; static;
  { hybrid in-place sorting based on quicksort with random pivot selection }
    class procedure QuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(var A: array of T; o: TSortOrder = soAsc); static;
  { hybrid in-place sorting based on V.Yaroslavskiy' dual pivot quicksort with random pivot selection }
    class procedure DualPivotQuickSort(var A: array of T; o: TSortOrder = soAsc); static;
  { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
    class procedure PDQSort(var A: array of T; o: TSortOrder = soAsc); static;
  { default sorting, currently PDQSort }
    class procedure Sort(var A: array of T; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T): TArray; static;
  end;

  { TGNumArrayHelper }
  generic TGNumArrayHelper<T> = class(specialize TGSimpleArrayHelper<T>)
  private
  type
    TItemType = (itUInt, itSInt, itFloat);
    TOffsets  = array[0..Pred(SizeOf(T)), 0..255] of SizeInt;
    TKeyBytes = array[0..Pred(SizeOf(T))] of Byte;

  class var
    CFKeyKind: TItemType;
    class constructor Init;
    class procedure FillOffsets(const  A: array of T; out aOfs: TOffsets); static;
    class procedure DoRxSortA(var A: array of T; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoRxSortD(var A: array of T; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoRadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder = soAsc); static;
  public
  { LSD radix sorting, requires O(N) auxiliary memory }
    class procedure RadixSort(var A: array of T; o: TSortOrder = soAsc); static;
    class procedure RadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder = soAsc); static;
  { default sorting, currently RadixSort if length of A > RADIX_CUTOFF,
    otherwise PDQSort }
    class procedure Sort(var A: array of T; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T): TArray; static;
  end;

  { TGOrdinalArrayHelper: for ordinal numeric types only }
  generic TGOrdinalArrayHelper<T> = class(specialize TGSimpleArrayHelper<T>)
  private
  type
    TMonoKind = (mkAsc, mkDesc, mkConst, mkNone);
    TGetAllow = function(aMin, aMax: T; aLen: SizeInt): Boolean;
    TOffsets  = array[0..Pred(SizeOf(T)), Byte] of SizeInt;

    class procedure CountSort(var A: array of T; aMinValue, aMaxValue: T; o:  TSortOrder); static;
    class function  TryInsertSortA2(var A: array of T; var aMin, aMax: T; L, R: SizeInt): SizeInt; static;
    class function  TryInsertSortD2(var A: array of T; var aMin, aMax: T; L, R: SizeInt): SizeInt; static;
    class function  Scan(var A: array of T; out aMinValue, aMaxValue: T): TMonoKind; static;
    class function  AllowCsSigned(aMin, aMax: T; aLen: SizeInt): Boolean; static;
    class function  AllowCsUnsigned(aMin, aMax: T; aLen: SizeInt): Boolean; static;
    class procedure FillOffsets(const  A: array of T; out aOfs: TOffsets); static;
    class procedure DoRxSortA(var A: array of T; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoRxSortD(var A: array of T; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoRadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder); static;
    class constructor Init;
  class var
    CountSortAllow: TGetAllow;
    CFItemSize: Integer;
    CFSigned: Boolean;
  public
    class function  CreateRange(aFirst, aLast: T): TArray; static;
    class function  CreateRandomRangePermutation(aRangeFirst, aRangeLast: T): TArray; static;
  { LSD radix sorting, requires O(N) auxiliary memory }
    class procedure RadixSort(var A: array of T; o: TSortOrder = soAsc); static;
    class procedure RadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder = soAsc); static;
  { hybrid sorting, will use counting sort (if possible) or radix sort }
    class procedure Sort(var A: array of T; o: TSortOrder = soAsc); static;
    class function  Sorted(const A: array of T; o: TSortOrder = soAsc): TArray; static;
  { copies only distinct values from A }
    class function  SelectDistinct(const A: array of T): TArray; static;
  end;

  TSizeIntHelper = specialize TGOrdinalArrayHelper<SizeInt>;

  { TGRadixSorter provides stable LSD radix sorting, requires O(N) auxiliary memory;
      TKey is the type for which LSD radix sort is appropriate(any integer or float type);
      TMap must provide class function GetKey([const[ref]] aItem: TItem): TKey; }
  generic TGRadixSorter<TItem, TKey, TMap> = record
  public
  type
    TArray = array of TItem;
    PItem    = ^TItem;

  private
  type
    TKeyType  = (ktUInt, ktSInt, ktFloat);
    TOffsets  = array[0..Pred(SizeOf(TKey)), 0..255] of SizeInt;
    TKeyBytes = array[0..Pred(SizeOf(TKey))] of Byte;
    THelper   = specialize TGBaseArrayHelper<TItem, TGRadixSorter>;

  const
    RADIX_CUTOFF   = 255;
    RADIX_BUF_SIZE = 1024;
  class var
    CFKeyKind: TKeyType;
    class constructor Init;
    class procedure FillOffsets(const  A: array of TItem; out aOfs: TOffsets); static;
    class procedure DoSortA(var A: array of TItem; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoSortD(var A: array of TItem; aBuf: PItem; var aOfs: TOffsets); static;
    class procedure DoSort(var A: array of TItem; var aBuf: TArray; o: TSortOrder = soAsc); static;
  public
    class function  Less(const L, R: TItem): Boolean; static; //inline;
    class procedure Sort(var A: array of TItem; o: TSortOrder = soAsc); static;
    class procedure Sort(var A: array of TItem; var aBuf: TArray; o: TSortOrder = soAsc); static;
  end;

  { TGSegmentTree after O(N) preprocessing of a given array of monoid elements allows:
      - find the value of the monoid function on an arbitrary range of array elements in O(log N);
      - update the array elements in O(log N);
        functor TMonoid must provide:
          field/property/function Identity: T; - neutral element of the monoid;
          associative dyadic function BinOp([const[ref]] L, R: T): T; }
  generic TGSegmentTree<T, TMonoid> = record
  type
    TOnGetElem   = procedure(aIndex: SizeInt; out aElem: T) of object;
    TNestGetElem = procedure(aIndex: SizeInt; out aElem: T) is nested;
  private
  type
    THelper      = specialize TGArrayHelpUtil<T>;
  var
    FTree: array of T;
    FElemCount,
    FLeafBound: SizeInt;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    class function GetIdentity: T; static;
    class operator Initialize(var st: TGSegmentTree); inline;
  public
    constructor Create(const a: array of T);
    constructor Create(aSize: SizeInt; aOnGetElem: TOnGetElem);
    constructor Create(aSize: SizeInt; aOnGetElem: TNestGetElem);
    function  RangeQuery(L, R: SizeInt): T;
    property  Count: SizeInt read FElemCount;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    class property Identity: T read GetIdentity;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}{$GOTO ON}{$TYPEDADDRESS ON}

{ TSearchResult }

constructor TSearchResult.Create(aFoundIndex, aInsertIndex: SizeInt);
begin
  FoundIndex := aFoundIndex;
  InsertIndex := aInsertIndex;
end;

{ TGArrayHelpUtil.TMergeSortBase }

procedure TGArrayHelpUtil.TMergeSortBase.PushRun(aBase, aCount: SizeInt);
begin
  if FStackCount = FStackSize then
    begin
      FStackSize += FStackSize;
      System.SetLength(FDynStack, FStackSize );
      if FStack = @FInitStack[0] then
        System.Move(FInitStack[0], Pointer(FDynStack)^, MERGE_STACK_SIZE * SizeOf(TRun));
      FStack := Pointer(FDynStack);
    end;
  FStack[FStackCount].Base := aBase;
  FStack[FStackCount].Count := aCount;
  Inc(FStackCount);
end;

function TGArrayHelpUtil.TMergeSortBase.EnsureBufferSize(aSize: SizeInt): PItem;
begin
  if aSize > MERGE_BUFFER_SIZE then
    begin
      if aSize > System.Length(FDynBuffer) then
        System.SetLength(FDynBuffer, LGUtils.RoundUpTwoPower(aSize));
      Result := Pointer(FDynBuffer);
    end
  else
    Result := Pointer(@FBuffer[0]);
end;

procedure TGArrayHelpUtil.TMergeSortBase.Init(A: PItem);
begin
  FData := A;
  FStackCount := 0;
  FStackSize := MERGE_STACK_SIZE;
  FDynBuffer := nil;
  FDynStack := nil;
  FStack := @FInitStack[0];
end;

class function TGArrayHelpUtil.TMergeSortBase.MinRunLen(aTotalSize: SizeInt): SizeInt;
var
  s: SizeInt;
begin
  if aTotalSize > MIN_MERGE_LEN then
    begin
      s := LGUtils.NSB(aTotalSize) - MIN_MERGE_POW;
      Result := aTotalSize shr s;
      Result += Ord((Result shl s xor aTotalSize) <> 0);
    end
  else
    Result := aTotalSize;
end;

{ TGArrayHelpUtil.TBlockQSortBase }

class procedure TGArrayHelpUtil.TBlockQSortBase.SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
  aNum: SizeInt; aUseSwaps: Boolean);
var
  L, R: PItem;
  I: SizeInt;
  v: TFake;
begin
  if aUseSwaps then
    for I := 0 to Pred(aNum) do
      begin
        v := TFake((aFirst + SizeInt(aOffsetsL[I]))^);
        TFake((aFirst + SizeInt(aOffsetsL[I]))^) := TFake((aLast - SizeInt(aOffsetsR[I]))^);
        TFake((aLast - SizeInt(aOffsetsR[I]))^) := v;
      end
  else
    if aNum > 0 then
      begin
        L := aFirst + SizeInt(aOffsetsL[0]);
        R := aLast - SizeInt(aOffsetsR[0]);
        v := TFake(L^);
        TFake(L^) := TFake(R^);
        for I := 1 to Pred(aNum) do
          begin
            L := aFirst + SizeInt(aOffsetsL[I]);
            TFake(R^) := TFake(L^);
            R := aLast - SizeInt(aOffsetsR[I]);
            TFake(L^) := TFake(R^);
          end;
        TFake(R^) := v;
      end;
end;

{ TGArrayHelpUtil.TReverseEnumerator }

function TGArrayHelpUtil.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrent^;
end;

constructor TGArrayHelpUtil.TReverseEnumerator.Create(aFirst, aLast: PItem);
begin
  FFirst := aFirst;
  FCurrent := aLast;
end;

function TGArrayHelpUtil.TReverseEnumerator.GetEnumerator: TReverseEnumerator;
begin
  Result := Self;
end;

function TGArrayHelpUtil.TReverseEnumerator.MoveNext: Boolean;
begin
  if FCurrent > FFirst then
    begin
      Dec(FCurrent);
      exit(True);
    end;
  Result := False;
end;

{ TGArrayHelpUtil }

class procedure TGArrayHelpUtil.CopyItems(aSrc, aDst: PItem; aCount: SizeInt);
begin
  if (aDst <> aSrc) and (aCount > 0) then  //else nothing to do
    begin
      if IsManagedType(T) then
        begin
          if aDst > aSrc then // forward copy
            begin
              aSrc += aCount - 1;
              aDst += aCount - 1;
              while aCount >= 4 do
                begin
                  aDst[ 0] := aSrc[ 0];
                  aDst[-1] := aSrc[-1];
                  aDst[-2] := aSrc[-2];
                  aDst[-3] := aSrc[-3];
                  aSrc -= 4;
                  aDst -= 4;
                  aCount -= 4;
                end;
              case aCount of
                1: aDst[0] := aSrc[0];
                2:
                  begin
                    aDst[ 0] := aSrc[ 0];
                    aDst[-1] := aSrc[-1];
                  end;
                3:
                  begin
                    aDst[ 0] := aSrc[ 0];
                    aDst[-1] := aSrc[-1];
                    aDst[-2] := aSrc[-2];
                  end;
              end;
            end
          else              // backward copy
            begin
              while aCount >= 4 do
                begin
                  aDst[0] := aSrc[0];
                  aDst[1] := aSrc[1];
                  aDst[2] := aSrc[2];
                  aDst[3] := aSrc[3];
                  aSrc += 4;
                  aDst += 4;
                  aCount -= 4;
                end;
              case aCount of
                1: aDst[0] := aSrc[0];
                2:
                  begin
                    aDst[0] := aSrc[0];
                    aDst[1] := aSrc[1];
                  end;
                3:
                  begin
                    aDst[0] := aSrc[0];
                    aDst[1] := aSrc[1];
                    aDst[2] := aSrc[2];
                  end;
              end;
            end;
        end
      else
        System.Move(aSrc^, aDst^, aCount * SizeOf(T));
    end;
end;

class procedure TGArrayHelpUtil.DoReverse(p: PItem; R: SizeInt);
var
  v0, v1, v2, v3: TFake;
  L: SizeInt;
begin
  L := 0;
  while R - L >= 7 do
    begin
      v0 := TFake(p[L    ]);
      v1 := TFake(p[L + 1]);
      v2 := TFake(p[L + 2]);
      v3 := TFake(p[L + 3]);
      TFake(p[L    ]) := TFake(p[R    ]);
      TFake(p[L + 1]) := TFake(p[R - 1]);
      TFake(p[L + 2]) := TFake(p[R - 2]);
      TFake(p[L + 3]) := TFake(p[R - 3]);
      TFake(p[R    ]) := v0;
      TFake(p[R - 1]) := v1;
      TFake(p[R - 2]) := v2;
      TFake(p[R - 3]) := v3;
      L += 4;
      R -= 4;
    end;
  case R - L of
    1..2:
      begin
        v0 := TFake(p[L]);
        TFake(p[L]) := TFake(p[R]);
        TFake(p[R]) := v0;
      end;
    3..4:
      begin
        v0 := TFake(p[L    ]);
        v1 := TFake(p[L + 1]);
        TFake(p[L    ]) := TFake(p[R    ]);
        TFake(p[L + 1]) := TFake(p[R - 1]);
        TFake(p[R    ]) := v0;
        TFake(p[R - 1]) := v1;
      end;
    5..6:
      begin
        v0 := TFake(p[L    ]);
        v1 := TFake(p[L + 1]);
        v2 := TFake(p[L + 2]);
        TFake(p[L    ]) := TFake(p[R    ]);
        TFake(p[L + 1]) := TFake(p[R - 1]);
        TFake(p[L + 2]) := TFake(p[R - 2]);
        TFake(p[R    ]) := v0;
        TFake(p[R - 1]) := v1;
        TFake(p[R - 2]) := v2;
      end;
  end;
end;

class procedure TGArrayHelpUtil.PtrSwap(var L, R: Pointer);
var
  tmp: Pointer;
begin
  tmp := L;
  L := R;
  R := tmp;
end;

class procedure TGArrayHelpUtil.Swap(var L, R: T);
var
  v: TFake;
begin
  v := TFake(L);
  TFake(L) := TFake(R);
  TFake(R) := v;
end;

class procedure TGArrayHelpUtil.SwapItems(var A: array of T; L, R: SizeInt);
var
  v: TFake;
begin
  if SizeUInt(L) < SizeUInt(System.Length(A)) then
    if SizeUInt(R) < SizeUInt(System.Length(A)) then
      begin
        v := TFake(A[L]);
        TFake(A[L]) := TFake(A[R]);
        TFake(A[R]) := v;
      end
    else
      raise EArgumentException.CreateFmt(SEArrIndexOutOfBoundsFmt, [R])
  else
    raise EArgumentException.CreateFmt(SEArrIndexOutOfBoundsFmt, [L]);
end;

class function TGArrayHelpUtil.CreateCopy(const A: array of T): TArray;
begin
  System.SetLength(Result, System.Length(A));
  if System.Length(Result) > 0 then
    CopyItems(@A[0], PItem(Result), System.Length(Result))
end;

class function TGArrayHelpUtil.CreateReverseCopy(const A: array of T): TArray;
var
  L, R: SizeInt;
begin
  R := System.High(A);
  System.SetLength(Result, Succ(R));
  if R >= 0 then
    begin
      L := 0;
      while R >= 3 do
        begin
          Result[R    ] := A[L    ];
          Result[R - 1] := A[L + 1];
          Result[R - 2] := A[L + 2];
          Result[R - 3] := A[L + 3];
          L += 4;
          R -= 4;
        end;
      case R of
        0: Result[R] := A[L];
        1:
          begin
            Result[R    ] := A[L    ];
            Result[R - 1] := A[L + 1];
          end;
        2:
          begin
            Result[R    ] := A[L    ];
            Result[R - 1] := A[L + 1];
            Result[R - 2] := A[L + 2];
          end;
      end;
    end;
end;

class function TGArrayHelpUtil.CreateMerge(const L, R: array of T): TArray;
var
  LenL, LenR: SizeInt;
begin
  LenL := System.Length(L);
  LenR := System.Length(R);
  System.SetLength(Result, LenL + LenR);
  if LenL > 0 then
    CopyItems(@L[0], @Result[0], LenL);
  if LenR > 0 then
    CopyItems(@R[0], @Result[LenL], LenR);
end;

class function TGArrayHelpUtil.CreateRandomShuffle(const A: array of T): TArray;
begin
  Result := CreateCopy(A);
  RandomShuffle(Result);
end;

class function TGArrayHelpUtil.CreateAndFill(const aValue: T; aSize: SizeInt): TArray;
var
  I: SizeInt;
begin
  if aSize < 1 then
    exit(nil);
  System.SetLength(Result, aSize);
  I := 0;
  while I <= aSize - 4 do
    begin
      Result[I  ] := aValue;
      Result[I+1] := aValue;
      Result[I+2] := aValue;
      Result[I+3] := aValue;
      I += 4;
    end;
  case aSize - I of
    1: Result[I] := aValue;
    2:
      begin
        Result[I  ] := aValue;
        Result[I+1] := aValue;
      end;
    3:
      begin
        Result[I  ] := aValue;
        Result[I+1] := aValue;
        Result[I+2] := aValue;
      end;
  end;
end;

class procedure TGArrayHelpUtil.Fill(var A: array of T; const aValue: T);
var
  I: SizeInt = 0;
begin
  while I <= System.Length(A) - 4 do
    begin
      A[I  ] := aValue;
      A[I+1] := aValue;
      A[I+2] := aValue;
      A[I+3] := aValue;
      I += 4;
    end;
  case System.Length(A) - I of
    1: A[I] := aValue;
    2:
      begin
        A[I  ] := aValue;
        A[I+1] := aValue;
      end;
    3:
      begin
        A[I  ] := aValue;
        A[I+1] := aValue;
        A[I+2] := aValue;
      end;
  end;
end;

class function TGArrayHelpUtil.Resize(var A: TArray; aNewSize: SizeInt): TArray;
begin
  System.SetLength(A, aNewSize);
  Result := A;
end;

class function TGArrayHelpUtil.Append(var A: TArray; const aValue: T): SizeInt;
begin
  Result := System.Length(A);
  System.SetLength(A, Succ(Result));
  A[Result] := aValue;
end;

class function TGArrayHelpUtil.CopyFrom(const aSource: array of T; var aTarget: array of T): SizeInt;
begin
  Result := Math.Min(System.Length(aSource), System.Length(aTarget));
  if Result > 0 then
    CopyItems(@aSource[0], @aTarget[0], Result);
end;

class function TGArrayHelpUtil.Merge(var aDst, aSrc: TArray): SizeInt;
var
  DstLen: SizeInt;
begin
  if aSrc <> aDst then
    begin
      Result := System.Length(aSrc);
      if Result > 0 then
        begin
          DstLen := System.Length(aDst);
          System.SetLength(aDst, DstLen + Result);
          System.Move(aSrc[0], aDst[DstLen], SizeOf(T) * Result);
          if IsManagedType(T) then
            System.FillChar(aSrc[0], SizeOf(T) * Result, 0);
          System.SetLength(aSrc, 0);
        end;
    end
  else
    Result := 0;
end;

class function TGArrayHelpUtil.Concat(const A: array of TArray): TArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  J := 0;
  for I := 0 to System.High(A) do
    J += System.Length(A[I]);
  System.SetLength(Result, J);
  J := 0;
  for I := 0 to System.High(A) do
    begin
      CopyItems(Pointer(A[I]), @Result[J], System.Length(A[I]));
      J += System.Length(A[I]);
    end;
end;

class function TGArrayHelpUtil.Split(var A: TArray; aIndex: SizeInt): TArray;
var
  ALen, RLen: SizeInt;
begin
  if A = nil then
    exit(nil);
  if aIndex < 0 then
    aIndex := 0;
  ALen := System.Length(A);
  if aIndex < ALen then
    begin
      RLen := ALen - aIndex;
      System.SetLength(Result, RLen);
      System.Move(A[aIndex], Result[0], SizeOf(T) * RLen);
      if IsManagedType(T) then
        System.FillChar(A[aIndex], SizeOf(T) * RLen, 0);
      System.SetLength(A, aIndex);
    end
  else
    Result := nil;
end;

class function TGArrayHelpUtil.Extract(var A: TArray; aIndex, aCount: SizeInt): TArray;
var
  Len: SizeInt;
begin
  if (A = nil) or (aCount < 1) then
    exit(nil);
  if aIndex < 0 then
    aIndex := 0;
  Len := System.Length(A);
  if aIndex < Len then
    begin
      aCount := Math.Min(aCount, Len - aIndex);
      System.SetLength(Result, aCount);
      if aCount > 0 then
        begin
          System.Move(A[aIndex], Result[0], SizeOf(T) * aCount);
          Len -= aCount;
          if Len - aIndex > 0 then
            System.Move(A[aIndex + aCount], A[aIndex], SizeOf(T) * (Len - aIndex));
          if IsManagedType(T) then
            System.FillChar(A[Len], SizeOf(T) * aCount, 0);
          System.SetLength(A, Len);
        end;
    end
  else
    Result := nil;
end;

class procedure TGArrayHelpUtil.Reverse(var A: array of T);
begin
  if System.High(A) > 0 then
    DoReverse(@A[0], System.High(A));
end;

class function TGArrayHelpUtil.ReverseOrder(const A: array of T): TReverseEnumerator;
begin
  if System.Length(A) <> 0 then
    Result := TReverseEnumerator.Create(@A[0], PItem(@A[System.High(A)]) + 1)
  else
    Result := TReverseEnumerator.Create(nil, nil);
end;

class procedure TGArrayHelpUtil.RotateLeft(var A: array of T; aDist: SizeInt);
var
  Len: SizeInt;
begin
  if (aDist = 0) or (Abs(aDist) >= System.Length(A)) then
    exit;
  Len := System.Length(A);
  if aDist < 0 then
    aDist += Len;
  DoReverse(@A[0], Pred(aDist));
  DoReverse(@A[aDist], Pred(Len - aDist));
  DoReverse(@A[0], Pred(Len));
end;

class procedure TGArrayHelpUtil.RotateRight(var A: array of T; aDist: SizeInt);
begin
  if (aDist = 0) or (Abs(aDist) >= System.Length(A)) then
    exit;
  if aDist > 0 then
    RotateLeft(A, System.Length(A) - aDist)
  else
    RotateLeft(A, -aDist);
end;


class procedure TGArrayHelpUtil.RandomShuffle(var A: array of T);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := System.High(A) downto 1 do
    begin
      J := Random(I+1);
      v := TFake(A[I]);
      TFake(A[I]) := TFake(A[J]);
      TFake(A[J]) := v;
    end;
end;

class function TGArrayHelpUtil.SequentSearch(const A: array of T; const aValue: T;
  c: TEqualCompare): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if c(aValue, A[Result]) then
      exit;
  Result := -1;
end;

class function TGArrayHelpUtil.SequentSearch(const A: array of T; const aValue: T;
  c: TOnEqualCompare): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if c(aValue, A[Result]) then
      exit;
  Result := -1;
end;

class function TGArrayHelpUtil.SequentSearch(const A: array of T; const aValue: T;
  c: TNestEqualCompare): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if c(aValue, A[Result]) then
      exit;
  Result := -1;
end;

class function TGArrayHelpUtil.Same(const A, B: array of T; c: TEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if not c(A[I], B[I]) then
        exit(False);
  Result := True;
end;

class function TGArrayHelpUtil.Same(const A, B: array of T; c: TOnEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if not c(A[I], B[I]) then
        exit(False);
  Result := True;
end;

class function TGArrayHelpUtil.Same(const A, B: array of T; c: TNestEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if not c(A[I], B[I]) then
        exit(False);
  Result := True;
end;

class function TGArrayHelpUtil.Select(const A: array of T; aTest: TTest): TArray;
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit(nil);
  System.SetLength(Result, System.Length(A));
  J := 0;
  for I := 0 to System.High(A) do
    if aTest(A[I]) then
      begin
        Result[J] := A[I];
        Inc(J);
      end;
  SetLength(Result, J);
end;

class function TGArrayHelpUtil.Select(const A: array of T; aTest: TOnTest): TArray;
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit(nil);
  System.SetLength(Result, System.Length(A));
  J := 0;
  for I := 0 to System.High(A) do
    if aTest(A[I]) then
      begin
        Result[J] := A[I];
        Inc(J);
      end;
  SetLength(Result, J);
end;

class function TGArrayHelpUtil.Select(const A: array of T; aTest: TNestTest): TArray;
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit(nil);
  System.SetLength(Result, System.Length(A));
  J := 0;
  for I := 0 to System.High(A) do
    if aTest(A[I]) then
      begin
        Result[J] := A[I];
        Inc(J);
      end;
  SetLength(Result, J);
end;

class procedure TGArrayHelpUtil.RemoveIf(var A: TArray; aTest: TTest);
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit;
  J := 0;
  for I := 0 to System.High(A) do
    begin
      if aTest(A[I]) then continue;
      if I <> J then
        A[J] := A[I];
      Inc(J);
    end;
end;

class procedure TGArrayHelpUtil.RemoveIf(var A: TArray; aTest: TOnTest);
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit;
  J := 0;
  for I := 0 to System.High(A) do
    begin
      if aTest(A[I]) then continue;
      if I <> J then
        A[J] := A[I];
      Inc(J);
    end;
end;

class procedure TGArrayHelpUtil.RemoveIf(var A: TArray; aTest: TNestTest);
var
  I, J: SizeInt;
begin
  if System.Length(A) = 0 then exit;
  J := 0;
  for I := 0 to System.High(A) do
    begin
      if aTest(A[I]) then continue;
      if I <> J then
        A[J] := A[I];
      Inc(J);
    end;
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TFold; const aInitVal: T): T;
var
  v: T;
begin
  Result := aInitVal;
  for v in A do
    Result := aFold(v, Result);
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := 0 to System.High(A) do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TOnFold; const aInitVal: T): T;
var
  v: T;
begin
  Result := aInitVal;
  for v in A do
    Result := aFold(v, Result);
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TOnFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := 0 to System.High(A) do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TNestFold; const aInitVal: T): T;
var
  v: T;
begin
  Result := aInitVal;
  for v in A do
    Result := aFold(v, Result);
end;

class function TGArrayHelpUtil.FoldL(const A: array of T; aFold: TNestFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := 0 to System.High(A) do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TFold; const aInitVal: T): T;
var
  I: SizeInt;
begin
  Result := aInitVal;
  for I := System.High(A) downto 0 do
    Result := aFold(A[I], Result);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := System.High(A) downto 0 do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TOnFold; const aInitVal: T): T;
var
  I: SizeInt;
begin
  Result := aInitVal;
  for I := System.High(A) downto 0 do
    Result := aFold(A[I], Result);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TOnFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := System.High(A) downto 0 do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TNestFold; const aInitVal: T): T;
var
  I: SizeInt;
begin
  Result := aInitVal;
  for I := System.High(A) downto 0 do
    Result := aFold(A[I], Result);
end;

class function TGArrayHelpUtil.FoldR(const A: array of T; aFold: TNestFold): TOptional;
var
  v: T;
  I: SizeInt;
begin
  if System.High(A) < 0 then exit(Default(TOptional));
  v := Default(T);
  for I := System.High(A) downto 0 do
    v := aFold(A[I], v);
  Result.Assign(v);
end;

{ TGIndexedHelpUtil }

class procedure TGIndexedHelpUtil.Swap(L, R: PItem);
var
  v: TFake;
begin
  v := TFake(L^);
  TFake(L^) := TFake(R^);
  TFake(R^) := v;
end;

class procedure TGIndexedHelpUtil.DoReverse(var e: TIndexed; L, R: SizeInt);
begin
  while L < R do
    begin
      Swap(e.UncMutable[L], e.UncMutable[R]);
      Inc(L);
      Dec(R);
    end;
end;

class function TGIndexedHelpUtil.CreateCopy(const aEntity: TIndexed; aFrom, aCount: SizeInt): TArray;
var
  I: SizeInt;
  a: TArray = nil;
begin
  if aFrom < aEntity.Count then
    begin
      aCount := Math.Min(aCount, aEntity.Count - aFrom);
      System.SetLength(a, aCount);
      for I := 0 to System.High(a) do
        a[I] := aEntity.UncMutable[I + aFrom]^;
      exit(a);
    end;
  Result := nil;
end;

class procedure TGIndexedHelpUtil.Reverse(var aEntity: TIndexed);
var
  R: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R > 0 then
    DoReverse(aEntity, 0, R);
end;

class procedure TGIndexedHelpUtil.Reverse(var aEntity: TIndexed; aFirst, aLast: SizeInt);
begin
  if aLast < aEntity.Count then
    if aFirst < aEntity.Count then
      DoReverse(aEntity, aFirst, aLast)
    else
      raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aFirst])
  else
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aLast]);
end;

class procedure TGIndexedHelpUtil.RandomShuffle(var aEntity: TIndexed);
var
  I: SizeInt;
begin
  for I := Pred(aEntity.Count) downto 1 do
    Swap(aEntity.UncMutable[I], aEntity.UncMutable[Random(I+1)]);
end;

class function TGIndexedHelpUtil.SequentSearch(const aEntity: TIndexed; const aValue: T;
  c: TEqualCompare): SizeInt;
begin
  for Result := 0 to Pred(aEntity.Count) do
    if c(aEntity.UncMutable[Result]^, aValue) then
      exit;
  Result := NULL_INDEX;
end;

class function TGIndexedHelpUtil.SequentSearch(const aEntity: TIndexed; const aValue: T;
  c: TOnEqualCompare): SizeInt;
begin
  for Result := 0 to Pred(aEntity.Count) do
    if c(aEntity.UncMutable[Result]^, aValue) then
      exit;
  Result := NULL_INDEX;
end;

class function TGIndexedHelpUtil.SequentSearch(const aEntity: TIndexed; const aValue: T;
  c: TNestEqualCompare): SizeInt;
begin
  for Result := 0 to Pred(aEntity.Count) do
    if c(aEntity.UncMutable[Result]^, aValue) then
      exit;
  Result := NULL_INDEX;
end;

class function TGIndexedHelpUtil.Same(const e1, e2: TIndexed; c: TEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if e1.Count <> e2.Count then
    exit(False);
  for I := 0 to Pred(e1.Count) do
    if not c(e1.UncMutable[I]^, e2.UncMutable[I]^) then
      exit(False);
  Result := True;
end;

class function TGIndexedHelpUtil.Same(const e1, e2: TIndexed; c: TOnEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if e1.Count <> e2.Count then
    exit(False);
  for I := 0 to Pred(e1.Count) do
    if not c(e1.UncMutable[I]^, e2.UncMutable[I]^) then
      exit(False);
  Result := True;
end;

class function TGIndexedHelpUtil.Same(const e1, e2: TIndexed; c: TNestEqualCompare): Boolean;
var
  I: SizeInt;
begin
  if e1.Count <> e2.Count then
    exit(False);
  for I := 0 to Pred(e1.Count) do
    if not c(e1.UncMutable[I]^, e2.UncMutable[I]^) then
      exit(False);
  Result := True;
end;

{ TGBaseArrayHelper.TMergeSort }

procedure TGBaseArrayHelper.TMergeSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.MergeAtA(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoA(Base, CountLo, CountHi)
  else
    MergeHiA(Base, CountLo, CountHi);
end;

procedure TGBaseArrayHelper.TMergeSort.MergeAtD(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoD(Base, CountLo, CountHi)
  else
    MergeHiD(Base, CountLo, CountHi);
end;

procedure TGBaseArrayHelper.TMergeSort.MergeLoA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if TCmpRel.Less(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountLo);
    {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
    {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
    {$ENDIF}
      if not TCmpRel.Less(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not TCmpRel.Less(LocA[pHi], LocB[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T)); ///
          {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
          {$ENDIF}
        end
      else
        begin
        {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));///
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));   ///
        {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
        {$ENDIF}
        end;
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.MergeLoD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if TCmpRel.Less(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountLo);
    {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T)); ///
    {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
    {$ENDIF}
      if not TCmpRel.Less(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not TCmpRel.Less(LocB[pLo], LocA[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));///
          {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
          {$ENDIF}
        end
      else
        begin
        {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));///
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));   ///
        {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
        {$ENDIF}
        end;
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.MergeHiA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if TCmpRel.Less(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountHi);
    {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));///
    {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
    {$ENDIF}
      if not TCmpRel.Less(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if TCmpRel.Less(LocB[pHi], LocA[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T)); ///
          {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
          {$ENDIF}
        end
      else
        begin
        {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T)); ///
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));  ///
        {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
        {$ENDIF}
        end;
    end;
end;

procedure TGBaseArrayHelper.TMergeSort.MergeHiD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if TCmpRel.Less(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountHi);
    {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T)); ///
    {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
    {$ENDIF}
      if not TCmpRel.Less(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if TCmpRel.Less(LocA[pLo], LocB[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T)); ///
          {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
          {$ENDIF}
        end
      else
        begin
        {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T)); ///
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));              ///
        {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
        {$ENDIF}
        end;
    end;
end;

class procedure TGBaseArrayHelper.TMergeSort.InsertSortA(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and TCmpRel.Less(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGBaseArrayHelper.TMergeSort.InsertSortD(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and TCmpRel.Less(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGBaseArrayHelper.TMergeSort.CountRunAsc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not TCmpRel.Less(A[1], A[0]) then  // ascending
        while (Result < R) and not TCmpRel.Less(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                                  // descending
        begin
          while (Result < R) and TCmpRel.Less(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGBaseArrayHelper.TMergeSort.CountRunDesc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not TCmpRel.Less(A[0], A[1]) then  // descending
        while (Result < R) and  not TCmpRel.Less(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                                  // ascending
        begin
          while (Result < R) and TCmpRel.Less(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGBaseArrayHelper.TMergeSort.SortAsc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A);
      L := 0;
      MinLen := MinRunLen(R - L + 1);
       repeat
         RunLen := Succ(CountRunAsc(@A[L], R - L));
         if RunLen < MinLen then
           begin
             Len := Math.Min(Succ(R - L), MinLen);
             InsertSortA(@A[L], Pred(Len), RunLen);
             RunLen := Len;
           end;
         ms.PushRun(L, RunLen);
         L += RunLen;
         ms.CollapseA;
       until L > R;
       ms.ForceCollapseA;
    end;
end;

class procedure TGBaseArrayHelper.TMergeSort.SortDesc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A);
      L := 0;
      MinLen := MinRunLen(R - L + 1);
       repeat
         RunLen := Succ(CountRunDesc(@A[L], R - L));
         if RunLen < MinLen then
           begin
             Len := Math.Min(Succ(R - L), MinLen);
             InsertSortD(@A[L], Pred(Len), RunLen);
             RunLen := Len;
           end;
         ms.PushRun(L, RunLen);
         L += RunLen;
         ms.CollapseD;
       until L > R;
       ms.ForceCollapseD;
    end
  else;
end;

{ TGBaseArrayHelper.TBlockQSort }

class procedure TGBaseArrayHelper.TBlockQSort.Sort3(A, B, C: PItem);
var
  v: TFake;
begin
  if TCmpRel.Less(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
  if TCmpRel.Less(C^, B^) then
    begin
      v := TFake(B^);
      TFake(B^) := TFake(C^);
      TFake(C^) := v;
    end;
  if TCmpRel.Less(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
end;

function TGBaseArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem): TPart;
var
  Pivot: T;
  v: TFake;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not TCmpRel.Less(First^, Pivot);
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if TCmpRel.Less(Last^, Pivot) then
          break;
      end
  else
    repeat Dec(Last) until TCmpRel.Less(Last^, Pivot);

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := TFake(First^);
      TFake(First^) :=  TFake(Last^);
      TFake(Last^) := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not TCmpRel.Less(It^, Pivot));
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not TCmpRel.Less((It + 1)^, Pivot));
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not TCmpRel.Less((It + 2)^, Pivot));
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not TCmpRel.Less((It + 3)^, Pivot));
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not TCmpRel.Less((It + 4)^, Pivot));
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not TCmpRel.Less((It + 5)^, Pivot));
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not TCmpRel.Less((It + 6)^, Pivot));
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not TCmpRel.Less((It + 7)^, Pivot));
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt(TCmpRel.Less((It - 1)^, Pivot));
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt(TCmpRel.Less((It - 2)^, Pivot));
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt(TCmpRel.Less((It - 3)^, Pivot));
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt(TCmpRel.Less((It - 4)^, Pivot));
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt(TCmpRel.Less((It - 5)^, Pivot));
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt(TCmpRel.Less((It - 6)^, Pivot));
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt(TCmpRel.Less((It - 7)^, Pivot));
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt(TCmpRel.Less((It - 8)^, Pivot));
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not TCmpRel.Less(It^, Pivot));
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(TCmpRel.Less(It^, Pivot));
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := TFake((First + (OffsetsL + NumL)^)^);
          TFake((First + (OffsetsL + NumL)^)^) := TFake(Last^);
          TFake(Last^) := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := TFake((Last - (OffsetsR + NumR)^)^);
          TFake((Last - (OffsetsR + NumR)^)^) := TFake(First^);
          TFake(First^) := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGBaseArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean);
var
  PivotPos: PItem;
  v: TFake;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGBaseArrayHelper.InsertionSort(aStart, Pred(aFinish - aStart))
          else
            TGBaseArrayHelper.UnguardInsertionSort(aStart, Pred(aFinish - aStart));
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1));
          v := TFake(aStart^);
          TFake(aStart^) := TFake((aStart + S2)^);
          TFake((aStart + S2)^) := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1);
      if not aLeftMost and not TCmpRel.Less((aStart - 1)^, aStart^) then
        begin
          aStart := PartitionLeft(aStart, aFinish) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish);

      PivotPos := PartResult.F1;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      if (LSize < Size div 8) or (RSize < Size div 8) then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGBaseArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart));
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := TFake(aStart^);
              TFake(aStart^) := TFake((aStart + LSizeDiv)^);
              TFake((aStart + LSizeDiv)^) := v;
              v := TFake((PivotPos - 1)^);
              TFake((PivotPos - 1)^) := TFake((PivotPos - LSizeDiv)^);
              TFake((PivotPos - LSizeDiv)^) := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((aStart + 1)^);
                  TFake((aStart + 1)^) := TFake((aStart + (LSizeDiv + 1))^);
                  TFake((aStart + (LSizeDiv + 1))^) := v;
                  v := TFake((aStart + 2)^);
                  TFake((aStart + 2)^) := TFake((aStart + (LSizeDiv + 2))^);
                  TFake((aStart + (LSizeDiv + 2))^) := v;
                  v := TFake((PivotPos - 2)^);
                  TFake((PivotPos - 2)^) := TFake((PivotPos - (LSizeDiv + 1))^);
                  TFake((PivotPos - (LSizeDiv + 1))^) := v;
                  v := TFake((PivotPos - 3)^);
                  TFake((PivotPos - 3)^) := TFake((PivotPos - (LSizeDiv + 2))^);
                  TFake((PivotPos - (LSizeDiv + 2))^) := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := TFake((PivotPos + 1)^);
              TFake((PivotPos + 1)^) := TFake((PivotPos + (1 + RSizeDiv))^);
              TFake((PivotPos + (1 + RSizeDiv))^) := v;
              v := TFake((aFinish - 1)^);
              TFake((aFinish - 1)^) := TFake((aFinish - RSizeDiv)^);
              TFake((aFinish - RSizeDiv)^) := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((PivotPos + 2)^);
                  TFake((PivotPos + 2)^) := TFake((PivotPos + (2 + RSizeDiv))^);
                  TFake((PivotPos + (2 + RSizeDiv))^) := v;
                  v := TFake((PivotPos + 3)^);
                  TFake((PivotPos + 3)^) := TFake((PivotPos + (3 + RSizeDiv))^);
                  TFake((PivotPos + (3 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 2)^);
                  TFake((aFinish - 2)^) := TFake((aFinish - (1 + RSizeDiv))^);
                  TFake((aFinish - (1 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 3)^);
                  TFake((aFinish - 3)^) := TFake((aFinish - (2 + RSizeDiv))^);
                  TFake((aFinish - (2 + RSizeDiv))^) := v;
                end;
            end;
        end
      else
        if PartResult.F2 and PartialInsertionSort(aStart, PivotPos) and
           PartialInsertionSort(PivotPos + 1, aFinish) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGBaseArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem): Boolean;
var
  Limit: SizeInt;
  Curr, Sift: PItem;
  v: TFake;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if TCmpRel.Less(Sift^, (Sift - 1)^) then
        begin
          v := TFake(Sift^);
          repeat
            TFake(Sift^) := TFake((Sift - 1)^);
            Dec(Sift);
          until (Sift = aStart) or not TCmpRel.Less(T(v), (Sift - 1)^);
          TFake(Sift^) := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGBaseArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem): PItem;
var
  Pivot: T;
  v: TFake;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until not TCmpRel.Less(Pivot, Last^);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if TCmpRel.Less(Pivot, First^) then
          break;
      end
  else
    repeat Inc(First) until TCmpRel.Less(Pivot, First^);

  while First < Last do
    begin
      v := TFake(First^);
      TFake(First^) := TFake(Last^);
      TFake(Last^) := v;
      repeat Dec(Last) until not TCmpRel.Less(Pivot, Last^);
      repeat Inc(First) until TCmpRel.Less(Pivot, First^);
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGBaseArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True);
end;

{ TGBaseArrayHelper }

class function TGBaseArrayHelper.TryInsertSortA(A: PItem; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if TCmpRel.Less(A[I], A[I-1]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not TCmpRel.Less(T(v), A[J-1]);
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGBaseArrayHelper.TryInsertSortD(A: PItem; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if TCmpRel.Less(A[I-1], A[I]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not TCmpRel.Less(A[J-1], T(v));
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGBaseArrayHelper.CountRun(A: PItem; R: SizeInt; o: TSortOrder): SizeInt;
begin
  Result := 0;
  while (Result < R) and not
        (TCmpRel.Less(A[Result], A[Succ(Result)])or TCmpRel.Less(A[Succ(Result)], A[Result])) do
    Inc(Result);
  if Result < R then
    if TCmpRel.Less(A[Result], A[Succ(Result)]) then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, Result);
      end
    else                                               // descending
      begin
        Result := TryInsertSortD(A, Result, R);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, Result);
      end;
end;

class procedure TGBaseArrayHelper.InsertionSort(A: PItem; R: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if TCmpRel.Less(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not TCmpRel.Less(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class procedure TGBaseArrayHelper.UnguardInsertionSort(A: PItem; R: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if TCmpRel.Less(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until not TCmpRel.Less(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class function TGBaseArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(A[M], aValue) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGBaseArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(aValue, A[M]) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGBaseArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(aValue, A[M]) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGBaseArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(A[M], aValue) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGBaseArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if TCmpRel.Less(A[0], A[R]) then  //ascending
    begin
      if TCmpRel.Less(aValue, A[0]) or TCmpRel.Less(A[R], aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue);
      if not(TCmpRel.Less(A[R], aValue) or TCmpRel.Less(aValue, A[R])) then
        Result := R;
    end
  else
    if TCmpRel.Less(A[R], A[0]) then   //descending
      begin
        if TCmpRel.Less(A[0], aValue) or TCmpRel.Less(aValue, A[R]) then
          exit;
        R := BiSearchLeftD(A, R, aValue);
        if not(TCmpRel.Less(A[R], aValue) or TCmpRel.Less(aValue, A[R])) then
          Result := R;
      end
    else           //constant
      if not(TCmpRel.Less(A[0], aValue) or TCmpRel.Less(aValue, A[0])) then
        Result := 0;
end;

class function TGBaseArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if TCmpRel.Less(A[0], A[R]) then  //ascending
    begin
      if TCmpRel.Less(aValue, A[0]) then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if TCmpRel.Less(A[R], aValue) then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue);
      Result.InsertIndex := R;
      if not(TCmpRel.Less(A[R], aValue) or TCmpRel.Less(aValue, A[R])) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if not(TCmpRel.Less(A[Pred(R)], aValue) or TCmpRel.Less(aValue, A[Pred(R)])) then
            Result.FoundIndex := Pred(R);
    end
  else
    if TCmpRel.Less(A[R], A[0]) then  //descending
      begin
        if TCmpRel.Less(A[0], aValue) then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if TCmpRel.Less(aValue, A[R]) then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue);
        Result.InsertIndex := R;
        if not(TCmpRel.Less(A[R], aValue) or TCmpRel.Less(aValue, A[R])) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if not(TCmpRel.Less(A[Pred(R)], aValue) or TCmpRel.Less(aValue, A[Pred(R)])) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      if TCmpRel.Less(aValue, A[0]) then
        Result.InsertIndex := 0
      else
        begin
          Result.InsertIndex := Succ(R);
          if not TCmpRel.Less(A[0], aValue) then
            Result.FoundIndex := R;
        end;
end;

class procedure TGBaseArrayHelper.DoHeapSort(A: PItem; R: SizeInt);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(A[Curr]);
          while Next <= R do
            begin
              if(Next < R) and TCmpRel.Less(A[Next], A[Succ(Next)]) then
                Inc(Next);
              if not TCmpRel.Less(T(v), A[Next]) then
                break;
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(A[Curr]) := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(A[I]);
          TFake(A[I]) := TFake(A[0]);
          while Next < I do
            begin
              if(Succ(Next) < I) and TCmpRel.Less(A[Next], A[Succ(Next)]) then
                Inc(Next);
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and TCmpRel.Less(A[Next], T(v)) do
            begin
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(A[Curr]) := v;
        end;
    end
  else
    InsertionSort(A, R);
end;

class function TGBaseArrayHelper.QSplitR(A: PItem; R: SizeInt): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  Pivot := A[Succ(Random(Pred(R)))];
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not TCmpRel.Less(A[pL], Pivot);
    repeat Dec(pR) until not TCmpRel.Less(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGBaseArrayHelper.DoQSort(A: PItem; R: SizeInt; aLeftmost: Boolean);
begin
  while R > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, R) do
      if Left <= R - Right then
        begin
          DoQSort(A, Left, aLeftmost);
          A := @A[Right];
          R -= Right;
          aLeftmost := False;
        end
      else
        begin
          DoQSort(@A[Right], R - Right, False);
          R := Left;
        end;
  if R > 0 then
    if aLeftmost then
      InsertionSort(A, R)
    else
      UnguardInsertionSort(A, R);
end;

class function TGBaseArrayHelper.MedianOf3(p1, p2, p3: PItem): PItem;
begin
  Result := p2;
  if TCmpRel.Less(p1^, Result^) then
    begin
      if TCmpRel.Less(p3^, Result^) then
        begin
          if TCmpRel.Less(p1^, p3^) then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if TCmpRel.Less(Result^, p3^) then
        begin
          if TCmpRel.Less(p3^, p1^) then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGBaseArrayHelper.QSplitMo9(A: PItem; R: SizeInt): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  if R > MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(A, @A[R shr 3], @A[R shr 2]),
      MedianOf3(@A[R shr 1 - R shr 3], @A[R shr 1], @A[R shr 1 + R shr 3]),
      MedianOf3(@A[R - R shr 2], @A[R - R shr 3], @A[R]))^
  else
    Pivot := MedianOf3(A, @A[R shr 1], @A[R])^;
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not TCmpRel.Less(A[pL], Pivot);
    repeat Dec(pR) until not TCmpRel.Less(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGBaseArrayHelper.DoIntroSort(A: PItem; R, Ttl: SizeInt; aLeftmost: Boolean);
begin
  if R > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, R) do
        begin
          if Left > 0 then
            DoIntroSort(A, Left, Pred(Ttl), aLeftmost);
          if Right < R then
            DoIntroSort(@A[Right], R - Right, Pred(Ttl), False);
        end
    else
      DoHeapSort(A, R)
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R)
      else
        UnguardInsertionSort(A, R);
end;

class function TGBaseArrayHelper.DPQSplit(A: PItem; R: SizeInt): TSortSplit;
var
  v, Pivot1, Pivot2: TFake;
  pL, pR, I: SizeInt;
begin
  pL := Succ(Random(Pred(R shr 1)));
  //pR := Pred(R - Random(Pred(R shr 1)));
  pR := pL + R shr 1;

  if not TCmpRel.Less(A[pR], A[pL]) then
    begin
      Pivot1 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[0]);
      Pivot2 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[R]);
    end
  else
    begin
      Pivot2 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[R]);
      Pivot1 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[0]);
    end;

  pL := 1;
  I  := 1;
  pR := Pred(R);
  while I <= pR do
    begin
      v := TFake(A[I]);
      if TCmpRel.Less(T(v), T(Pivot1)) then
        begin
          TFake(A[I]) := TFake(A[pL]);
          TFake(A[pL]) := v;
          Inc(pL);
        end
      else
        if TCmpRel.Less(T(Pivot2), T(v)) then
          begin
            while (pR >= I) and TCmpRel.Less(T(Pivot2), A[pR]) do
              Dec(pR);
            if pR < I then
              break;
            if TCmpRel.Less(A[pR], T(Pivot1)) then
              begin
                TFake(A[I]) := TFake(A[pL]);
                TFake(A[pL]) := TFake(A[pR]);
                Inc(pL);
              end
            else
              TFake(A[I]) := TFake(A[pR]);
            TFake(A[pR]) := v;
            Dec(pR);
          end;
      Inc(I);
    end;

  TFake(A[0]) := TFake(A[pL - 1]);
  TFake(A[pL - 1]) := Pivot1;
  TFake(A[R]) := TFake(A[pR + 1]);
  TFake(A[pR + 1]) := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGBaseArrayHelper.DoDPQSort(A: PItem; R: SizeInt; aLeftmost: Boolean);
begin
  if R > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, R) do
      begin
        DoDPQSort(A, Left - 1, aLeftmost);
        DoDPQSort(@A[Right + 1], R - Right - 1, False);
        if TCmpRel.Less(A[Left], A[Right]) then
          DoDPQSort(@A[Left + 1], Right - Left - 2, False);
      end
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R)
      else
        UnguardInsertionSort(A, R);
end;

class function TGBaseArrayHelper.QSelectR(A: PItem; R, N: SizeInt): T;
var
  v: TFake;
  Pivot: T;
  L, pL, pR: SizeInt;
begin
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until not TCmpRel.Less(A[pL], Pivot);
        repeat Dec(pR) until not TCmpRel.Less(Pivot, A[pR]);
        if pL >= pR then break;
        v := TFake(A[pL]);
        TFake(A[pL]) := TFake(A[pR]);
        TFake(A[pR]) := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and TCmpRel.Less(A[R], A[L]) then
    begin
      v := TFake(A[L]);
      TFake(A[L]) := TFake(A[R]);
      TFake(A[R]) := v;
    end;
  Result := A[N];
end;

class function TGBaseArrayHelper.SequentSearch(const A: array of T; const aValue: T): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if not(TCmpRel.Less(A[Result], aValue) or TCmpRel.Less(aValue, A[Result])) then
      exit;
  Result := NULL_INDEX;
end;

class function TGBaseArrayHelper.BinarySearch(const A: array of T; const aValue: T): SizeInt;
begin
  Result := System.High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue);
end;

class function TGBaseArrayHelper.BinarySearchPos(const A: array of T; const aValue: T): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGBaseArrayHelper.IndexOfMin(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  m: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      m := A[0];
      for I := 1 to R do
        if TCmpRel.Less(A[I], m) then
          begin
            m := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGBaseArrayHelper.IndexOfMax(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  m: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      m := A[0];
      for I := 1 to R do
        if TCmpRel.Less(m, A[I]) then
          begin
            m := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGBaseArrayHelper.GetMin(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMin(A, v) then
    Result.Assign(v);
end;

class function TGBaseArrayHelper.GetMax(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMax(A, v) then
    Result.Assign(v);
end;

class function TGBaseArrayHelper.FindMin(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if TCmpRel.Less(A[I], aValue) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGBaseArrayHelper.FindMax(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if TCmpRel.Less(aValue, A[I]) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGBaseArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if TCmpRel.Less(aMax, A[I]) then
          aMax := A[I]
        else
          if TCmpRel.Less(A[I], aMin) then
            aMin := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGBaseArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue));
  if N >= R then
    exit(FindMax(A, aValue));
  aValue := QSelectR(@A[0], R, N);
  Result := True;
end;

class function TGBaseArrayHelper.NthSmallest(var A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v) then
    Result.Assign(v);
end;

class function TGBaseArrayHelper.FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue);
end;

class function TGBaseArrayHelper.NthSmallestND(const A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v) then
    Result.Assign(v);
end;

class function TGBaseArrayHelper.NextPermutation2Asc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if TCmpRel.Less(A[Succ(I)], A[I]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if TCmpRel.Less(A[I], A[J]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGBaseArrayHelper.NextPermutation2Desc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if TCmpRel.Less(A[I], A[Succ(I)]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if TCmpRel.Less(A[J], A[I]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGBaseArrayHelper.IsPermutation(const A, aPerm: array of T): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA);
  Sort(LocPerm);
  Result := Same(LocA, LocPerm);
end;

class function TGBaseArrayHelper.IsNonDescending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if TCmpRel.Less(A[Succ(I)], A[I]) then
      exit(False);
  Result := True;
end;

class function TGBaseArrayHelper.IsStrictAscending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 0 to Pred(R) do
        if not TCmpRel.Less(A[I], A[Succ(I)]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGBaseArrayHelper.IsNonAscending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if TCmpRel.Less(A[I], A[Succ(I)]) then
      exit(False);
  Result := True;
end;

class function TGBaseArrayHelper.IsStrictDescending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 0 to Pred(R) do
        if not TCmpRel.Less(A[Succ(I)], A[I]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGBaseArrayHelper.InversionCount(var A: array of T): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and not TCmpRel.Less(A[J], A[I]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGBaseArrayHelper.InversionCountND(const A: array of T): Int64;
begin
  Result := InversionCount(CreateCopy(A));
end;

class function TGBaseArrayHelper.IsSubSequence(const A, aSeq: array of T): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if not (TCmpRel.Less(A[I], aSeq[J]) or TCmpRel.Less(A[I], aSeq[J])) then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGBaseArrayHelper.LisI(const A: array of T): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if TCmpRel.Less(A[TailIdx[M]], v) then
          L := Succ(M)
        else
          R := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if TCmpRel.Less(A[I], A[TailIdx[0]]) then
      TailIdx[0] := I
    else
      if TCmpRel.Less(A[TailIdx[Pred(Len)]], A[I]) then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGBaseArrayHelper.Lis(const A: array of T): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGBaseArrayHelper.Same(const A, B: array of T): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if TCmpRel.Less(A[I], B[I]) or TCmpRel.Less(B[I], A[I]) then
        exit(False);
  Result := True;
end;

class procedure TGBaseArrayHelper.QuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoQSort(@A[0], R, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGBaseArrayHelper.IntroSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGBaseArrayHelper.DualPivotQuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoDPQSort(@A[0], R, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGBaseArrayHelper.PDQSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGBaseArrayHelper.MergeSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if o = soAsc then
      TMergeSort.SortAsc(@A[0], R)
    else
      TMergeSort.SortDesc(@A[0], R);
end;

class procedure TGBaseArrayHelper.Sort(var A: array of T; o: TSortOrder);
begin
  PDQSort(A, o);
end;

class function TGBaseArrayHelper.Sorted(const A: array of T; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, o);
end;

class function TGBaseArrayHelper.SelectDistinct(const A: array of T): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if not (TCmpRel.Less(Result[I], Result[J]) or TCmpRel.Less(Result[J], Result[I])) then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGBaseIndexedHelper }

class function TGBaseIndexedHelper.BiSearchLeftA(const e: TIndexed; L, R: SizeInt;
  const aValue: T): SizeInt;
var
  M: SizeInt;
begin
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(e.UncMutable[M]^, aValue) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGBaseIndexedHelper.BiSearchLeftD(const e: TIndexed; L, R: SizeInt;
  const aValue: T): SizeInt;
var
  M: SizeInt;
begin
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(aValue, e.UncMutable[M]^) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGBaseIndexedHelper.BiSearchRightA(const e: TIndexed; L, R: SizeInt;
  const aValue: T): SizeInt;
var
  M: SizeInt;
begin
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(aValue, e.UncMutable[M]^) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGBaseIndexedHelper.BiSearchRightD(const e: TIndexed; L, R: SizeInt;
  const aValue: T): SizeInt;
var
  M: SizeInt;
begin
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if TCmpRel.Less(e.UncMutable[M]^, aValue) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGBaseIndexedHelper.DoBinSearch(const e: TIndexed; L, R: SizeInt;
  const aValue: T): SizeInt;
begin
  Result := NULL_INDEX;
  if TCmpRel.Less(e.UncMutable[L]^, e.UncMutable[R]^) then  //ascending
    begin
      if TCmpRel.Less(aValue, e.UncMutable[L]^) or TCmpRel.Less(e.UncMutable[R]^, aValue) then
        exit;
      R := BiSearchLeftA(e, L, R, aValue);
      if not(TCmpRel.Less(e.UncMutable[R]^, aValue) or TCmpRel.Less(aValue, e.UncMutable[R]^)) then
        Result := R;
    end
  else
    if TCmpRel.Less(e.UncMutable[R]^, e.UncMutable[L]^) then //descending
      begin
        if TCmpRel.Less(e.UncMutable[L]^, aValue) or
           TCmpRel.Less(aValue, e.UncMutable[R]^) then
          exit;
        R := BiSearchLeftD(e, L, R, aValue);
        if not(TCmpRel.Less(e.UncMutable[R]^, aValue) or TCmpRel.Less(aValue, e.UncMutable[R]^)) then
          Result := R;
      end
    else //constant
      if not(TCmpRel.Less(e.UncMutable[L]^, aValue) or TCmpRel.Less(aValue, e.UncMutable[L]^)) then
        Result := L;
end;

class function TGBaseIndexedHelper.DoBinSearchPos(const e: TIndexed; L, R: SizeInt;
  const aValue: T): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if TCmpRel.Less(e.UncMutable[L]^, e.UncMutable[R]^) then  //ascending
    begin
      if TCmpRel.Less(aValue, e.UncMutable[L]^) then
        begin
          Result.InsertIndex := L;
          exit;
        end
      else
        if TCmpRel.Less(e.UncMutable[R]^, aValue) then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(e, L, R, aValue);
      Result.InsertIndex := R;
      if not(TCmpRel.Less(e.UncMutable[R]^, aValue) or TCmpRel.Less(aValue, e.UncMutable[R]^)) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > L then
          if not(TCmpRel.Less(e.UncMutable[Pred(R)]^, aValue) or
                 TCmpRel.Less(aValue, e.UncMutable[Pred(R)]^)) then
            Result.FoundIndex := Pred(R);
    end
  else
    if TCmpRel.Less(e.UncMutable[R]^, e.UncMutable[L]^) then  //descending
      begin
        if TCmpRel.Less(e.UncMutable[L]^, aValue) then
          begin
            Result.InsertIndex := L;
            exit;
          end
        else
          if TCmpRel.Less(aValue, e.UncMutable[R]^) then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(e, L, R, aValue);
        Result.InsertIndex := R;
        if not(TCmpRel.Less(e.UncMutable[R]^, aValue) or TCmpRel.Less(aValue, e.UncMutable[R]^)) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > L then
            if not(TCmpRel.Less(e.UncMutable[Pred(R)]^, aValue) or
                   TCmpRel.Less(aValue, e.UncMutable[Pred(R)]^)) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      if TCmpRel.Less(aValue, e.UncMutable[L]^) then
        Result.InsertIndex := L
      else
        begin
          Result.InsertIndex := Succ(R);
          if not TCmpRel.Less(e.UncMutable[L]^, aValue) then
            Result.FoundIndex := R;
        end;
end;

class function TGBaseIndexedHelper.CountRun(var e: TIndexed; L, R: SizeInt; o: TSortOrder): SizeInt;
begin
  Result := L;
  while (Result < R) and not(TCmpRel.Less(e.UncMutable[Result]^, e.UncMutable[Succ(Result)]^)or
                             TCmpRel.Less(e.UncMutable[Succ(Result)]^, e.UncMutable[Result]^))do
    Inc(Result);
  if Result < R then
    begin
      Inc(Result);
      if TCmpRel.Less(e.UncMutable[Pred(Result)]^, e.UncMutable[Result]^) then   // ascending
        begin
          while (Result < R) and not TCmpRel.Less(e.UncMutable[Succ(Result)]^, e.UncMutable[Result]^) do
            Inc(Result);
          if (Result = R) and (o = soDesc)then
            DoReverse(e, L, Result);
        end
      else      // descending
        begin
          while (Result < R) and not TCmpRel.Less(e.UncMutable[Result]^, e.UncMutable[Succ(Result)]^) do
            Inc(Result);
          if (Result = R) and (o = soAsc)then
            DoReverse(e, L, Result);
        end;
    end;
end;

class procedure TGBaseIndexedHelper.InsertionSort(var e: TIndexed; L, R: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := Succ(L) to R do
    if TCmpRel.Less(e.UncMutable[I]^, e.UncMutable[I-1]^) then
      begin
        J := I;
        v := TFake(e.UncMutable[I]^);
        repeat
          TFake(e.UncMutable[J]^) := TFake(e.UncMutable[J-1]^);
          Dec(J);
        until (J = L) or not TCmpRel.Less(T(v), e.UncMutable[J-1]^);
        TFake(e.UncMutable[J]^) := v;
      end;
end;

class procedure TGBaseIndexedHelper.DoHeapSort(var e: TIndexed; L, R: SizeInt);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R - L > TUtil.HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R - L) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(e.UncMutable[Curr + L]^);
          while Next + L <= R do
            begin
              if (Next + L < R) and
                 TCmpRel.Less(e.UncMutable[Next + L]^, e.UncMutable[Succ(Next + L)]^) then
                Inc(Next);
              if not TCmpRel.Less(T(v), e.UncMutable[Next + L]^) then
                break;
              TFake(e.UncMutable[Curr + L]^) := TFake(e.UncMutable[Next + L]^);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(e.UncMutable[Curr + L]^) := v;
        end;
      for I := R - L downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(e.UncMutable[I + L]^);
          TFake(e.UncMutable[I + L]^) := TFake(e.UncMutable[L]^);
          while Next < I do
            begin
              if(Succ(Next) < I) and
                 TCmpRel.Less(e.UncMutable[Next + L]^, e.UncMutable[Succ(Next + L)]^) then
                Inc(Next);
              TFake(e.UncMutable[Curr + L]^) := TFake(e.UncMutable[Next + L]^);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and TCmpRel.Less(e.UncMutable[Next + L]^, T(v)) do
            begin
              TFake(e.UncMutable[Curr + L]^) := TFake(e.UncMutable[Next + L]^);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(e.UncMutable[Curr + L]^) := v;
        end;
    end
  else
    InsertionSort(e, L, R);
end;

class function TGBaseIndexedHelper.MedianOf3(p1, p2, p3: PItem): PItem;
begin
  Result := p2;
  if TCmpRel.Less(p1^, Result^) then
    begin
      if TCmpRel.Less(p3^, Result^) then
        begin
          if TCmpRel.Less(p1^, p3^) then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if TCmpRel.Less(Result^, p3^) then
        begin
          if TCmpRel.Less(p3^, p1^) then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGBaseIndexedHelper.QSplitMo9(var e: TIndexed; L, R: SizeInt): TSortSplit;
var
  Pivot: T;
  pL, pR: SizeInt;
begin
  if R - L > TUtil.MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(e.UncMutable[L],
                e.UncMutable[(R-L) shr 3 + L],
                e.UncMutable[(R-L) shr 2 + L]),
      MedianOf3(e.UncMutable[(R-L) shr 1 - (R) shr 3 + L],
                e.UncMutable[(R-L) shr 1 + L],
                e.UncMutable[(R-L) shr 1 + (R-L) shr 3 + L]),
      MedianOf3(e.UncMutable[R - (R-L) shr 2],
                e.UncMutable[R - (R-L) shr 3],
                e.UncMutable[R]))^
  else
    Pivot := MedianOf3(e.UncMutable[L], e.UncMutable[(R-L) shr 1 + L], e.UncMutable[R])^;
  pL := Pred(L);
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not TCmpRel.Less(e.UncMutable[pL]^, Pivot);
    repeat Dec(pR) until not TCmpRel.Less(Pivot, e.UncMutable[pR]^);
    if pL > pR then break;
    Swap(e.UncMutable[pL], e.UncMutable[pR]);
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGBaseIndexedHelper.DoIntroSort(var e: TIndexed; L, R, Ttl: SizeInt);
begin
  if R - L > TUtil.QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(e, L, R) do
        begin
          if Left > L then
            DoIntroSort(e, L, Left, Pred(Ttl));
          if Right < R then
            DoIntroSort(e, Right, R, Pred(Ttl));
        end
    else
      DoHeapSort(e, L, R)
  else
    InsertionSort(e, L, R);
end;

class function TGBaseIndexedHelper.SequentSearch(const aEntity: TIndexed; const aValue: T): SizeInt;
begin
  for Result := 0 to Pred(aEntity.Count) do
    if not(TCmpRel.Less(aEntity.UncMutable[Result]^, aValue) or
           TCmpRel.Less(aValue, aEntity.UncMutable[Result]^)) then
      exit;
  Result := NULL_INDEX;
end;

class function TGBaseIndexedHelper.BinarySearch(const aEntity: TIndexed; const aValue: T): SizeInt;
begin
  if aEntity.Count > 0 then
    exit(DoBinSearch(aEntity, 0, Pred(aEntity.Count), aValue));
  Result := NULL_INDEX;
end;

class function TGBaseIndexedHelper.BinarySearchPos(const aEntity: TIndexed;
  const aValue: T): TSearchResult;
begin
  if aEntity.Count > 0 then
    exit(DoBinSearchPos(aEntity, 0, Pred(aEntity.Count), aValue));
  Result := TSearchResult.Create(NULL_INDEX, 0);
end;

class function TGBaseIndexedHelper.IndexOfMin(const aEntity: TIndexed): SizeInt;
var
  R, I: SizeInt;
  m: T;
begin
  R := Pred(aEntity.Count);
  if R >= 0 then
    begin
      Result := 0;
      m := aEntity.UncMutable[0]^;
      for I := 1 to R do
        if TCmpRel.Less(aEntity.UncMutable[I]^, m) then
          begin
            m := aEntity.UncMutable[I]^;
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGBaseIndexedHelper.IndexOfMax(const aEntity: TIndexed): SizeInt;
var
  R, I: SizeInt;
  m: T;
begin
  R := Pred(aEntity.Count);
  if R >= 0 then
    begin
      Result := 0;
      m := aEntity.UncMutable[0]^;
      for I := 1 to R do
        if TCmpRel.Less(m, aEntity.UncMutable[I]^) then
          begin
            m := aEntity.UncMutable[I]^;
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGBaseIndexedHelper.GetMin(const aEntity: TIndexed): TOptional;
var
  v: T;
begin
  if FindMin(aEntity, v) then
    Result.Assign(v);
end;

class function TGBaseIndexedHelper.GetMax(const aEntity: TIndexed): TOptional;
var
  v: T;
begin
  if FindMax(aEntity, v) then
    Result.Assign(v);
end;

class function TGBaseIndexedHelper.FindMin(const aEntity: TIndexed; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R >= 0 then
    begin
      aValue := aEntity.UncMutable[0]^;
      for I := 1 to R do
        if TCmpRel.Less(aEntity.UncMutable[I]^, aValue) then
          aValue := aEntity.UncMutable[I]^;
      exit(True);
    end;
  Result := False;
end;

class function TGBaseIndexedHelper.FindMax(const aEntity: TIndexed; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R >= 0 then
    begin
      aValue := aEntity.UncMutable[0]^;
      for I := 1 to R do
        if TCmpRel.Less(aValue, aEntity.UncMutable[I]^) then
          aValue := aEntity.UncMutable[I]^;
      exit(True);
    end;
  Result := False;
end;

class function TGBaseIndexedHelper.FindMinMax(const aEntity: TIndexed; out aMin, aMax: T): Boolean;
var
  R, I: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R >= 0 then
    begin
      aMin := aEntity.UncMutable[0]^;
      aMax := aEntity.UncMutable[0]^;
      for I := 1 to R do
        if TCmpRel.Less(aMax, aEntity.UncMutable[I]^) then
          aMax := aEntity.UncMutable[I]^
        else
          if TCmpRel.Less(aEntity.UncMutable[I]^, aMin) then
            aMin := aEntity.UncMutable[I]^;
      exit(True);
    end;
  Result := False;
end;

class function TGBaseIndexedHelper.FindNthSmallest(const aEntity: TIndexed; N: SizeInt;
  out aValue: T): Boolean;
begin
  if (aEntity.Count > 0) and (SizeUInt(N) < SizeUInt(aEntity.Count)) then
    exit(specialize TGBaseArrayHelper<T, TCmpRel>
      .FindNthSmallest(CreateCopy(aEntity, 0, aEntity.Count), N, aValue));
  Result := False;
end;

class function TGBaseIndexedHelper.NthSmallest(const aEntity: TIndexed; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallest(aEntity, N, v) then
    Result.Assign(v);
end;

class function TGBaseIndexedHelper.NextPermutation2Asc(var aEntity: TIndexed): Boolean;
var
  I, J, R: SizeInt;
begin
  R := Pred(aEntity.Count);
  J := -1;
  for I := Pred(R) downto 0 do
    if TCmpRel.Less(aEntity.UncMutable[Succ(I)]^, aEntity.UncMutable[I]^) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if TCmpRel.Less(aEntity.UncMutable[I]^, aEntity.UncMutable[J]^) then
      begin
        Swap(aEntity.UncMutable[I], aEntity.UncMutable[J]);
        break;
      end;
  DoReverse(aEntity, Succ(J), R);
  Result := True;
end;

class function TGBaseIndexedHelper.NextPermutation2Desc(var aEntity: TIndexed): Boolean;
var
  I, J, R: SizeInt;
begin
  R := Pred(aEntity.Count);
  J := -1;
  for I := Pred(R) downto 0 do
    if TCmpRel.Less(aEntity.UncMutable[I]^, aEntity.UncMutable[Succ(I)]^) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if TCmpRel.Less(aEntity.UncMutable[J]^, aEntity.UncMutable[I]^) then
      begin
        Swap(aEntity.UncMutable[I], aEntity.UncMutable[J]);
        break;
      end;
  DoReverse(aEntity, Succ(J), R);
  Result := True;
end;

class function TGBaseIndexedHelper.InversionCount(const aEntity: TIndexed): Int64;
begin
  if aEntity.Count > 1 then
    exit(specialize TGBaseArrayHelper<T, TCmpRel>.InversionCount(CreateCopy(aEntity, 0, aEntity.Count)));
  Result := 0;
end;

class function TGBaseIndexedHelper.IsNonDescending(const aEntity: TIndexed): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to aEntity.Count - 2 do
    if TCmpRel.Less(aEntity.UncMutable[Succ(I)]^, aEntity.UncMutable[I]^) then
      exit(False);
  Result := True;
end;

class function TGBaseIndexedHelper.IsStrictAscending(const aEntity: TIndexed): Boolean;
var
  I, R: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R > 0 then
    begin
      for I := 0 to Pred(R) do
        if not TCmpRel.Less(aEntity.UncMutable[I]^, aEntity.UncMutable[Succ(I)]^) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGBaseIndexedHelper.IsNonAscending(const aEntity: TIndexed): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to aEntity.Count - 2 do
    if TCmpRel.Less(aEntity.UncMutable[I]^, aEntity.UncMutable[Succ(I)]^) then
      exit(False);
  Result := True;
end;

class function TGBaseIndexedHelper.IsStrictDescending(const aEntity: TIndexed): Boolean;
var
  I, R: SizeInt;
begin
  R := Pred(aEntity.Count);
  if R > 0 then
    begin
      for I := 0 to Pred(R) do
        if not TCmpRel.Less(aEntity.UncMutable[Succ(I)]^, aEntity.UncMutable[I]^) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGBaseIndexedHelper.Lis(const aEntity: TIndexed): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < Pred(R) do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if not TCmpRel.Less(aEntity.UncMutable[TailIdx[M]]^, v) then
          R := M
        else
          L := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  TailIdx := TSizeIntHelper.CreateAndFill(0, aEntity.Count);
  Parents := TSizeIntHelper.CreateAndFill(NULL_INDEX, aEntity.Count);
  Len := 1;
  for I := 1 to Pred(aEntity.Count) do
    if TCmpRel.Less(aEntity.UncMutable[I]^, aEntity.UncMutable[TailIdx[0]]^) then
      TailIdx[0] := I
    else
      if TCmpRel.Less(aEntity.UncMutable[TailIdx[Pred(Len)]]^, aEntity.UncMutable[I]^) then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(aEntity.UncMutable[I]^, Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := 0 to Pred(Len) do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  TSizeIntHelper.Reverse(r);
  Result := r;
end;

class function TGBaseIndexedHelper.Same(const e1, e2: TIndexed): Boolean;
var
  I: SizeInt;
begin
  if e1.Count <> e2.Count then
    exit(False);
  for I := 0 to Pred(e1.Count) do
    if TCmpRel.Less(e1.UncMutable[I]^, e2.UncMutable[I]^) or
       TCmpRel.Less(e2.UncMutable[I]^, e1.UncMutable[I]^) then
      exit(False);
  Result := True;
end;

class procedure TGBaseIndexedHelper.Sort(var aEntity: TIndexed; o: TSortOrder);
var
  R: SizeInt;
begin
  R := Pred(aEntity.Count);
  if (R > 0) and (CountRun(aEntity, 0, R, o) < R) then
    begin
      DoIntroSort(aEntity, 0, R, LGUtils.NSB(R + 1) * TUtil.INTROSORT_LOG_FACTOR);
      if o = soDesc then
        Reverse(aEntity);
    end;
end;

class procedure TGBaseIndexedHelper.Sort(var aEntity: TIndexed; aFirst, aLast: SizeInt; o: TSortOrder);
begin
  if aFirst >= aEntity.Count then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aFirst]);
  if aLast >= aEntity.Count then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aLast]);
  if (aFirst < aLast) and (CountRun(aEntity, aFirst, aLast, o) < aLast) then
    begin
      DoIntroSort(aEntity, aFirst, aLast, LGUtils.NSB(aLast-aFirst+1) * TUtil.INTROSORT_LOG_FACTOR);
      if o = soDesc then
        DoReverse(aEntity, aFirst, aLast);
    end;
end;

class function TGBaseIndexedHelper.SelectDistinct(const aEntity: TIndexed): TArray;
begin
  if aEntity.Count > 1 then
    exit(specialize TGBaseArrayHelper<T, TCmpRel>.SelectDistinct(CreateCopy(aEntity, 0, aEntity.Count)));
  Result := nil;
end;

{ TGComparableArrayHelper }

class function TGComparableArrayHelper.ValEqual(const L, R: T): Boolean;
begin
  Result := not((L < R) or (R < L));
end;

class function TGComparableArrayHelper.ValNotEqual(const L, R: T): Boolean;
begin
  Result := (L < R) or (R < L);
end;

{ TGComparableArrayHelper.TMergeSort }

procedure TGComparableArrayHelper.TMergeSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.MergeAtA(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoA(Base, CountLo, CountHi)
  else
    MergeHiA(Base, CountLo, CountHi);
end;

procedure TGComparableArrayHelper.TMergeSort.MergeAtD(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoD(Base, CountLo, CountHi)
  else
    MergeHiD(Base, CountLo, CountHi);
end;

procedure TGComparableArrayHelper.TMergeSort.MergeLoA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if FData[From + CountLo] < FData[Pred(From + CountLo)] then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if LocA[Pred(From + CountLo + CountHi)] < LocA[From] then
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));///
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));   ///
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end
      else
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if LocA[pHi] < LocB[pLo] then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end
            else
            begin
              TFake(LocA[pDst]) := TFake(LocB[pLo]);
              Inc(pLo);
            end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T)); ///
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end;
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.MergeLoD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if FData[Pred(From + CountLo)] < FData[From + CountLo] then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T)); ///
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if LocA[From] < LocA[Pred(From + CountLo + CountHi)] then
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));///
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));   ///
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end
      else
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if LocB[pLo] < LocA[pHi] then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));///
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end;
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.MergeHiA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if FData[From + CountLo] < FData[Pred(From + CountLo)] then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));///
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if LocA[Pred(From + CountLo + CountHi)] < LocA[From] then
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T)); ///
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));  ///
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end
      else
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if LocB[pHi] < LocA[pLo] then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T)); ///
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
    end;
end;

procedure TGComparableArrayHelper.TMergeSort.MergeHiD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
begin
  LocA := FData;
  if FData[Pred(From + CountLo)] < FData[From + CountLo] then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T)); ///
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if LocA[From] < LocA[Pred(From + CountLo + CountHi)] then
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T)); ///
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));              ///
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end
      else
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if LocA[pLo] < LocB[pHi] then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T)); ///
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end;
    end;
end;

class procedure TGComparableArrayHelper.TMergeSort.InsertSortA(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and (T(v) < A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGComparableArrayHelper.TMergeSort.InsertSortD(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and (A[J] < T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGComparableArrayHelper.TMergeSort.CountRunAsc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not(A[1] < A[0]) then// ascending
        while (Result < R) and not(A[Succ(Result)] < A[Result]) do
          Inc(Result)
      else                    // descending
        begin
          while (Result < R) and (A[Succ(Result)] < A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGComparableArrayHelper.TMergeSort.CountRunDesc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not (A[0] < A[1]) then // descending
        while (Result < R) and  not(A[Result] < A[Succ(Result)]) do
          Inc(Result)
      else                      // ascending
        begin
          while (Result < R) and (A[Result] < A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGComparableArrayHelper.TMergeSort.SortAsc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A);
      L := 0;
      MinLen := MinRunLen(R - L + 1);
       repeat
         RunLen := Succ(CountRunAsc(@A[L], R - L));
         if RunLen < MinLen then
           begin
             Len := Math.Min(Succ(R - L), MinLen);
             InsertSortA(@A[L], Pred(Len), RunLen);
             RunLen := Len;
           end;
         ms.PushRun(L, RunLen);
         L += RunLen;
         ms.CollapseA;
       until L > R;
       ms.ForceCollapseA;
    end;
end;

class procedure TGComparableArrayHelper.TMergeSort.SortDesc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A);
      L := 0;
      MinLen := MinRunLen(R - L + 1);
       repeat
         RunLen := Succ(CountRunDesc(@A[L], R - L));
         if RunLen < MinLen then
           begin
             Len := Math.Min(Succ(R - L), MinLen);
             InsertSortD(@A[L], Pred(Len), RunLen);
             RunLen := Len;
           end;
         ms.PushRun(L, RunLen);
         L += RunLen;
         ms.CollapseD;
       until L > R;
       ms.ForceCollapseD;
    end;
end;

{ TGComparableArrayHelper.TBlockQSort }

class procedure TGComparableArrayHelper.TBlockQSort.Sort3(A, B, C: PItem);
var
  v: TFake;
begin
  if B^ < A^ then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
  if C^ < B^ then
    begin
      v := TFake(B^);
      TFake(B^) := TFake(C^);
      TFake(C^) := v;
    end;
  if B^ < A^ then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
end;

function TGComparableArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem): TPart;
var
  Pivot: T;
  v: TFake;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not(First^ < Pivot);
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if Last^ < Pivot then
          break;
      end
  else
    repeat Dec(Last) until Last^ < Pivot;

  AlreadyPartitioned := not(First < Last);

  if not AlreadyPartitioned then
    begin
      v := TFake(First^);
      TFake(First^) :=  TFake(Last^);
      TFake(Last^) := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not(It^ < Pivot));
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not((It + 1)^ < Pivot));
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not((It + 2)^ < Pivot));
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not((It + 3)^ < Pivot));
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not((It + 4)^ < Pivot));
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not((It + 5)^ < Pivot));
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not((It + 6)^ < Pivot));
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not((It + 7)^ < Pivot));
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt((It - 1)^ < Pivot);
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt((It - 2)^ < Pivot);
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt((It - 3)^ < Pivot);
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt((It - 4)^ < Pivot);
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt((It - 5)^ < Pivot);
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt((It - 6)^ < Pivot);
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt((It - 7)^ < Pivot);
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt((It - 8)^ < Pivot);
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not(It^ < Pivot));
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(It^ < Pivot);
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := TFake((First + (OffsetsL + NumL)^)^);
          TFake((First + (OffsetsL + NumL)^)^) := TFake(Last^);
          TFake(Last^) := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := TFake((Last - (OffsetsR + NumR)^)^);
          TFake((Last - (OffsetsR + NumR)^)^) := TFake(First^);
          TFake(First^) := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGComparableArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt;
  aLeftMost: Boolean);
var
  PivotPos: PItem;
  v: TFake;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGComparableArrayHelper.InsertionSort(aStart, Pred(aFinish - aStart))
          else
            TGComparableArrayHelper.UnguardInsertionSort(aStart, Pred(aFinish - aStart));
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1));
          v := TFake(aStart^);
          TFake(aStart^) := TFake((aStart + S2)^);
          TFake((aStart + S2)^) := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1);
      if not aLeftMost and not((aStart - 1)^ < aStart^) then
        begin
          aStart := PartitionLeft(aStart, aFinish) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish);

      PivotPos := PartResult.F1;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      if (LSize < Size div 8) or (RSize < Size div 8) then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGComparableArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart));
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := TFake(aStart^);
              TFake(aStart^) := TFake((aStart + LSizeDiv)^);
              TFake((aStart + LSizeDiv)^) := v;
              v := TFake((PivotPos - 1)^);
              TFake((PivotPos - 1)^) := TFake((PivotPos - LSizeDiv)^);
              TFake((PivotPos - LSizeDiv)^) := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((aStart + 1)^);
                  TFake((aStart + 1)^) := TFake((aStart + (LSizeDiv + 1))^);
                  TFake((aStart + (LSizeDiv + 1))^) := v;
                  v := TFake((aStart + 2)^);
                  TFake((aStart + 2)^) := TFake((aStart + (LSizeDiv + 2))^);
                  TFake((aStart + (LSizeDiv + 2))^) := v;
                  v := TFake((PivotPos - 2)^);
                  TFake((PivotPos - 2)^) := TFake((PivotPos - (LSizeDiv + 1))^);
                  TFake((PivotPos - (LSizeDiv + 1))^) := v;
                  v := TFake((PivotPos - 3)^);
                  TFake((PivotPos - 3)^) := TFake((PivotPos - (LSizeDiv + 2))^);
                  TFake((PivotPos - (LSizeDiv + 2))^) := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := TFake((PivotPos + 1)^);
              TFake((PivotPos + 1)^) := TFake((PivotPos + (1 + RSizeDiv))^);
              TFake((PivotPos + (1 + RSizeDiv))^) := v;
              v := TFake((aFinish - 1)^);
              TFake((aFinish - 1)^) := TFake((aFinish - RSizeDiv)^);
              TFake((aFinish - RSizeDiv)^) := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((PivotPos + 2)^);
                  TFake((PivotPos + 2)^) := TFake((PivotPos + (2 + RSizeDiv))^);
                  TFake((PivotPos + (2 + RSizeDiv))^) := v;
                  v := TFake((PivotPos + 3)^);
                  TFake((PivotPos + 3)^) := TFake((PivotPos + (3 + RSizeDiv))^);
                  TFake((PivotPos + (3 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 2)^);
                  TFake((aFinish - 2)^) := TFake((aFinish - (1 + RSizeDiv))^);
                  TFake((aFinish - (1 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 3)^);
                  TFake((aFinish - 3)^) := TFake((aFinish - (2 + RSizeDiv))^);
                  TFake((aFinish - (2 + RSizeDiv))^) := v;
                end;
            end;
        end
      else
        if PartResult.F2 and PartialInsertionSort(aStart, PivotPos) and
           PartialInsertionSort(PivotPos + 1, aFinish) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGComparableArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem): Boolean;
var
  Curr, Sift: PItem;
  Limit: SizeInt;
  v: TFake;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if Sift^ < (Sift - 1)^ then
        begin
          v := TFake(Sift^);
          repeat
            TFake(Sift^) := TFake((Sift - 1)^);
            Dec(Sift);
          until (Sift = aStart) or not(T(v) < (Sift - 1)^);
          TFake(Sift^) := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGComparableArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem): PItem;
var
  Pivot: T;
  v: TFake;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until not(Pivot < Last^);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if Pivot < First^ then
          break;
      end
  else
    repeat Inc(First) until Pivot < First^;

  while First < Last do
    begin
      v := TFake(First^);
      TFake(First^) := TFake(Last^);
      TFake(Last^) := v;
      repeat Dec(Last) until not(Pivot < Last^);
      repeat Inc(First) until Pivot < First^;
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGComparableArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True);
end;

{ TGComparableArrayHelper }

class function TGComparableArrayHelper.TryInsertSortA(A: PItem; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I] < A[I-1] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not(T(v) < A[J-1]);
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGComparableArrayHelper.TryInsertSortD(A: PItem; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I-1] < A[I] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not(A[J-1] < T(v));
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGComparableArrayHelper.CountRun(A: PItem; R: SizeInt; o: TSortOrder): SizeInt;
begin
  Result := 0;
  while (Result < R) and ValEqual(A[Result], A[Succ(Result)]) do
    Inc(Result);
  if Result < R then
    if A[Result] < A[Succ(Result)] then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, Result);
      end
    else                                  // descending
      begin
        Result := TryInsertSortD(A, Result, R);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, Result);
      end;
end;

class procedure TGComparableArrayHelper.InsertionSort(A: PItem; R: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if A[I] < A[I-1] then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not(T(v) < A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class procedure TGComparableArrayHelper.UnguardInsertionSort(A: PItem; R: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if A[I] < A[I-1] then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until not(T(v) < A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class function TGComparableArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] < aValue then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGComparableArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if aValue < A[M] then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGComparableArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if aValue < A[M] then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGComparableArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] < aValue then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGComparableArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if A[0] < A[R] then   //ascending
    begin
      if (aValue < A[0]) or (A[R] < aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue);
      if ValEqual(A[R], aValue) then
        Result := R;
    end
  else
    if A[R] < A[0] then //descending
      begin
        if (A[0] < aValue) or (aValue < A[R]) then
          exit;
        R := BiSearchLeftD(A, R, aValue);
        if ValEqual(A[R], aValue) then
          Result := R;
      end
    else               //constant
      if ValEqual(A[0], aValue) then
        Result := 0;
end;

class function TGComparableArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if A[0] < A[R] then  //ascending
    begin
      if aValue < A[0] then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if A[R] < aValue then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue);
      Result.InsertIndex := R;
      if ValEqual(A[R], aValue) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if ValEqual(A[Pred(R)], aValue) then
            Result.FoundIndex := Pred(R);
    end
  else
    if A[R] < A[0] then  //descending
      begin
        if A[0] < aValue then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if aValue < A[R] then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue);
        Result.InsertIndex := R;
        if ValEqual(A[R], aValue) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if ValEqual(A[Pred(R)], aValue) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      if aValue < A[0] then
        Result.InsertIndex := 0
      else
        begin
          Result.InsertIndex := Succ(R);
          if ValEqual(A[0], aValue) then
            Result.FoundIndex := R;
        end;
end;

class procedure TGComparableArrayHelper.DoHeapSort(A: PItem; R: SizeInt);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(A[Curr]);
          while Next <= R do
            begin
              if(Next < R) and (A[Next] < A[Succ(Next)])then
                Inc(Next);
              if not(T(v) < A[Next]) then
                break;
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(A[Curr]) := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(A[I]);
          TFake(A[I]) := TFake(A[0]);
          while Next < I do
            begin
              if(Succ(Next) < I) and (A[Next] < A[Succ(Next)]) then
                Inc(Next);
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and (A[Next] < T(v)) do
            begin
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(A[Curr]) := v;
        end;
    end
  else
    InsertionSort(A, R);
end;

class function TGComparableArrayHelper.QSplitR(A: PItem; R: SizeInt): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  Pivot := A[Succ(Random(Pred(R)))]; //shouldn't be first or last
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not(A[pL] < Pivot);
    repeat Dec(pR) until not(Pivot < A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGComparableArrayHelper.DoQSort(A: PItem; R: SizeInt; aLeftmost: Boolean);
begin
  while R > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, R) do
      if Left <= R - Right then
        begin
          DoQSort(A, Left, aLeftmost);
          A := @A[Right];
          R -= Right;
          aLeftmost := False;
        end
      else
        begin
          DoQSort(@A[Right], R - Right, False);
          R := Left;
        end;
  if R > 0 then
    if aLeftmost then
      InsertionSort(A, R)
    else
      UnguardInsertionSort(A, R);
end;

class function TGComparableArrayHelper.MedianOf3(p1, p2, p3: PItem): PItem;
begin
  Result := p2;
  if p1^ < Result^ then
    begin
      if p3^ < Result^ then
        begin
          if p1^ < p3^ then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if Result^ < p3^ then
        begin
          if p3^ < p1^ then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGComparableArrayHelper.QSplitMo9(A: PItem; R: SizeInt): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  if R > MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(A, @A[R shr 3], @A[R shr 2]),
      MedianOf3(@A[R shr 1 - R shr 3], @A[R shr 1], @A[R shr 1 + R shr 3]),
      MedianOf3(@A[R - R shr 2], @A[R - R shr 3], @A[R]))^
  else
    Pivot := MedianOf3(A, @A[R shr 1], @A[R])^;
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not(A[pL] < Pivot);
    repeat Dec(pR) until not(Pivot < A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGComparableArrayHelper.DoIntroSort(A: PItem; R, Ttl: SizeInt; aLeftmost: Boolean);
begin
  if R > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, R) do
        begin
          if Left > 0 then
            DoIntroSort(A, Left, Pred(Ttl), aLeftmost);
          if Right < R then
            DoIntroSort(@A[Right], R - Right, Pred(Ttl), False);
        end
    else
      DoHeapSort(A, R)
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R)
      else
        UnguardInsertionSort(A, R);
end;

class function TGComparableArrayHelper.DPQSplit(A: PItem; R: SizeInt): TSortSplit;
var
  v, Pivot1, Pivot2: TFake;
  pL, pR, I: SizeInt;
begin
  pL := Succ(Random(Pred(R shr 1)));
  //pR := Pred(R - Random(Pred(R shr 1)));
  pR := pL + R shr 1;

  if A[pR] < A[pL] then
    begin
      Pivot2 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[R]);
      Pivot1 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[0]);
    end
  else
    begin
      Pivot1 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[0]);
      Pivot2 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[R]);
    end;
  pL := 1;
  I  := 1;
  pR := Pred(R);
  while I <= pR do
    begin
      v := TFake(A[I]);
      if T(v) < T(Pivot1) then
        begin
          TFake(A[I]) := TFake(A[pL]);
          TFake(A[pL]) := v;
          Inc(pL);
        end
      else
        if T(Pivot2) < T(v) then
          begin
            while (pR >= I) and (T(Pivot2) < A[pR]) do
              Dec(pR);
            if pR < I then
              break;
            if A[pR] < T(Pivot1) then
              begin
                TFake(A[I]) := TFake(A[pL]);
                TFake(A[pL]) := TFake(A[pR]);
                Inc(pL);
              end
            else
              TFake(A[I]) := TFake(A[pR]);
            TFake(A[pR]) := v;
            Dec(pR);
          end;
      Inc(I);
    end;

  TFake(A[0]) := TFake(A[pL - 1]);
  TFake(A[pL - 1]) := Pivot1;
  TFake(A[R]) := TFake(A[pR + 1]);
  TFake(A[pR + 1]) := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGComparableArrayHelper.DoDPQSort(A: PItem; R: SizeInt; aLeftmost: Boolean);
begin
  if R > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, R) do
      begin
        DoDPQSort(A, Left - 1, aLeftmost);
        DoDPQSort(@A[Right + 1], R - Right - 1, False);
        if A[Left] < A[Right] then
          DoDPQSort(@A[Left + 1], Right - Left - 2, False);
      end
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R)
      else
        UnguardInsertionSort(A, R);
end;

class function TGComparableArrayHelper.QSelectR(A: PItem; R, N: SizeInt): T;
var
  v: TFake;
  Pivot: T;
  L, pL, pR: SizeInt;
begin
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until not(A[pL] < Pivot);
        repeat Dec(pR) until not(Pivot < A[pR]);
        if pL >= pR then break;
        v := TFake(A[pL]);
        TFake(A[pL]) := TFake(A[pR]);
        TFake(A[pR]) := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and (A[R] < A[L]) then
    begin
      v := TFake(A[L]);
      TFake(A[L]) := TFake(A[R]);
      TFake(A[R]) := v;
    end;
  Result := A[N];
end;

class function TGComparableArrayHelper.SequentSearch(const A: array of T; const aValue: T): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if ValEqual(aValue, A[Result]) then
      exit;
  Result := NULL_INDEX;
end;

class function TGComparableArrayHelper.BinarySearch(const A: array of T; const aValue: T): SizeInt;
begin
  Result := System.High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue);
end;

class function TGComparableArrayHelper.BinarySearchPos(const A: array of T; const aValue: T): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGComparableArrayHelper.IndexOfMin(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if A[I] < v then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGComparableArrayHelper.IndexOfMax(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if v < A[I] then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGComparableArrayHelper.GetMin(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMin(A, v) then
    Result.Assign(v);
end;

class function TGComparableArrayHelper.GetMax(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMax(A, v) then
    Result.Assign(v);
end;

class function TGComparableArrayHelper.FindMin(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aValue := A[0];
      for I := 1 to R do
        if A[I] < aValue then
          aValue := A[I];
    end;
end;

class function TGComparableArrayHelper.FindMax(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aValue := A[0];
      for I := 1 to R do
        if aValue < A[I] then
          aValue := A[I];
    end;
end;

class function TGComparableArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if aMax < A[I] then
          aMax := A[I]
        else
          if A[I] < aMin then
            aMin := A[I];
    end;
end;

class function TGComparableArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue));
  if N >= R then
    exit(FindMax(A, aValue));
  aValue := QSelectR(@A[0], R, N);
  Result := True;
end;

class function TGComparableArrayHelper.NthSmallest(var A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v) then
    Result.Assign(v);
end;

class function TGComparableArrayHelper.FindNthSmallestND(const A: array of T; N: SizeInt;
  out aValue: T): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue);
end;

class function TGComparableArrayHelper.NthSmallestND(const A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v) then
    Result.Assign(v);
end;

class function TGComparableArrayHelper.NextPermutation2Asc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if A[Succ(I)] < A[I] then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if  A[I] < A[J] then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGComparableArrayHelper.NextPermutation2Desc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if A[I] < A[Succ(I)] then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if A[J] < A[I] then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGComparableArrayHelper.IsPermutation(const A, aPerm: array of T): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA);
  Sort(LocPerm);
  Result := Same(LocA, LocPerm);
end;

class function TGComparableArrayHelper.IsNonDescending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if A[Succ(I)] < A[I] then
      exit(False);
  Result := True;
end;

class function TGComparableArrayHelper.IsStrictAscending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not(A[Pred(I)] < A[I]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGComparableArrayHelper.IsNonAscending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if A[I] < A[Succ(I)] then
      exit(False);
  Result := True;
end;

class function TGComparableArrayHelper.IsStrictDescending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not(A[I] < A[Pred(I)]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGComparableArrayHelper.InversionCount(var A: array of T): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and not(A[J] < A[I]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGComparableArrayHelper.InversionCountND(const A: array of T): Int64;
begin
  Result := InversionCount(CreateCopy(A));
end;

class function TGComparableArrayHelper.IsSubSequence(const A, aSeq: array of T): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if not ((A[I] < aSeq[J]) or (aSeq[J] < A[I])) then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGComparableArrayHelper.LisI(const A: array of T): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if A[TailIdx[M]] < v then
          L := Succ(M)
        else
          R := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if A[I] < A[TailIdx[0]] then
      TailIdx[0] := I
    else
      if A[TailIdx[Pred(Len)]] < A[I] then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGComparableArrayHelper.Lis(const A: array of T): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGComparableArrayHelper.Same(const A, B: array of T): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if ValNotEqual(A[I], B[I]) then
        exit(False);
  Result := True;
end;

class procedure TGComparableArrayHelper.QuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoQSort(@A[0], R, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGComparableArrayHelper.IntroSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGComparableArrayHelper.DualPivotQuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      DoDPQSort(@A[0], R, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGComparableArrayHelper.PDQSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGComparableArrayHelper.MergeSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if o = soAsc then
      TMergeSort.SortAsc(@A[0], R)
    else
      TMergeSort.SortDesc(@A[0], R);
end;

class procedure TGComparableArrayHelper.Sort(var A: array of T; o: TSortOrder);
begin
  PDQSort(A, o);
end;

class function TGComparableArrayHelper.Sorted(const A: array of T; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, o);
end;

class function TGComparableArrayHelper.SelectDistinct(const A: array of T): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if ValEqual(Result[I], Result[J]) then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGRegularArrayHelper.TMergeSort }

procedure TGRegularArrayHelper.TMergeSort.Init(A: PItem; c: TLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGRegularArrayHelper.TMergeSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.MergeAtA(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoA(Base, CountLo, CountHi)
  else
    MergeHiA(Base, CountLo, CountHi);
end;

procedure TGRegularArrayHelper.TMergeSort.MergeAtD(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoD(Base, CountLo, CountHi)
  else
    MergeHiD(Base, CountLo, CountHi);
end;

procedure TGRegularArrayHelper.TMergeSort.MergeLoA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocA[pHi], LocB[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.MergeLoD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocB[pLo], LocA[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.MergeHiA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocB[pHi], LocA[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

procedure TGRegularArrayHelper.TMergeSort.MergeHiD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocA[pLo], LocB[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

class procedure TGRegularArrayHelper.TMergeSort.InsertSortA(A: PItem; R, At: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGRegularArrayHelper.TMergeSort.InsertSortD(A: PItem; R, At: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGRegularArrayHelper.TMergeSort.CountRunAsc(A: PItem; R: SizeInt; c: TLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                       // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGRegularArrayHelper.TMergeSort.CountRunDesc(A: PItem; R: SizeInt; c: TLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                       // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGRegularArrayHelper.TMergeSort.SortAsc(A: PItem; R: SizeInt; c: TLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseA;
      until L > R;
      ms.ForceCollapseA;
    end;
end;

class procedure TGRegularArrayHelper.TMergeSort.SortDesc(A: PItem; R: SizeInt; c: TLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseD;
      until L > R;
      ms.ForceCollapseD;
    end;
end;

{ TGRegularArrayHelper.TBlockQSort }

class procedure TGRegularArrayHelper.TBlockQSort.Sort3(A, B, D: PItem; c: TLess);
var
  v: TFake;
begin
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
  if c(D^, B^) then
    begin
      v := TFake(B^);
      TFake(B^) := TFake(D^);
      TFake(D^) := v;
    end;
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
end;

function TGRegularArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem; c: TLess): TPart;
var
  Pivot: T;
  v: TFake;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not c(First^, Pivot);
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if c(Last^, Pivot) then
          break;
      end
  else
    repeat Dec(Last) until c(Last^, Pivot);

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := TFake(First^);
      TFake(First^) :=  TFake(Last^);
      TFake(Last^) := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not c(It^, Pivot));
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not c((It + 1)^, Pivot));
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not c((It + 2)^, Pivot));
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not c((It + 3)^, Pivot));
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not c((It + 4)^, Pivot));
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not c((It + 5)^, Pivot));
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not c((It + 6)^, Pivot));
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not c((It + 7)^, Pivot));
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt(c((It - 1)^, Pivot));
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt(c((It - 2)^, Pivot));
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt(c((It - 3)^, Pivot));
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt(c((It - 4)^, Pivot));
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt(c((It - 5)^, Pivot));
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt(c((It - 6)^, Pivot));
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt(c((It - 7)^, Pivot));
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt(c((It - 8)^, Pivot));
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not c(It^, Pivot));
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(c(It^, Pivot));
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := TFake((First + (OffsetsL + NumL)^)^);
          TFake((First + (OffsetsL + NumL)^)^) := TFake(Last^);
          TFake(Last^) := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := TFake((Last - (OffsetsR + NumR)^)^);
          TFake((Last - (OffsetsR + NumR)^)^) := TFake(First^);
          TFake(First^) := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGRegularArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt;
  aLeftMost: Boolean; c: TLess);
var
  PivotPos: PItem;
  v: TFake;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
  AlreadyPartitioned, HighlyUnbalanced: Boolean;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGRegularArrayHelper.InsertionSort(aStart, Pred(aFinish - aStart), c)
          else
            TGRegularArrayHelper.UnguardInsertionSort(aStart, Pred(aFinish - aStart), c);
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1, c);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2, c);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3, c);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1), c);
          v := TFake(aStart^);
          TFake(aStart^) := TFake((aStart + S2)^);
          TFake((aStart + S2)^) := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1, c);
      if (not aLeftMost) and (not c((aStart - 1)^, aStart^)) then
        begin
          aStart := PartitionLeft(aStart, aFinish, c) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish, c);

      PivotPos := PartResult.F1;
      AlreadyPartitioned := PartResult.F2;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      HighlyUnbalanced := (LSize < Size div 8) or (RSize < Size div 8);
      if HighlyUnbalanced then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGRegularArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart), c);
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := TFake(aStart^);
              TFake(aStart^) := TFake((aStart + LSizeDiv)^);
              TFake((aStart + LSizeDiv)^) := v;
              v := TFake((PivotPos - 1)^);
              TFake((PivotPos - 1)^) := TFake((PivotPos - LSizeDiv)^);
              TFake((PivotPos - LSizeDiv)^) := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((aStart + 1)^);
                  TFake((aStart + 1)^) := TFake((aStart + (LSizeDiv + 1))^);
                  TFake((aStart + (LSizeDiv + 1))^) := v;
                  v := TFake((aStart + 2)^);
                  TFake((aStart + 2)^) := TFake((aStart + (LSizeDiv + 2))^);
                  TFake((aStart + (LSizeDiv + 2))^) := v;
                  v := TFake((PivotPos - 2)^);
                  TFake((PivotPos - 2)^) := TFake((PivotPos - (LSizeDiv + 1))^);
                  TFake((PivotPos - (LSizeDiv + 1))^) := v;
                  v := TFake((PivotPos - 3)^);
                  TFake((PivotPos - 3)^) := TFake((PivotPos - (LSizeDiv + 2))^);
                  TFake((PivotPos - (LSizeDiv + 2))^) := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := TFake((PivotPos + 1)^);
              TFake((PivotPos + 1)^) := TFake((PivotPos + (1 + RSizeDiv))^);
              TFake((PivotPos + (1 + RSizeDiv))^) := v;
              v := TFake((aFinish - 1)^);
              TFake((aFinish - 1)^) := TFake((aFinish - RSizeDiv)^);
              TFake((aFinish - RSizeDiv)^) := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((PivotPos + 2)^);
                  TFake((PivotPos + 2)^) := TFake((PivotPos + (2 + RSizeDiv))^);
                  TFake((PivotPos + (2 + RSizeDiv))^) := v;
                  v := TFake((PivotPos + 3)^);
                  TFake((PivotPos + 3)^) := TFake((PivotPos + (3 + RSizeDiv))^);
                  TFake((PivotPos + (3 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 2)^);
                  TFake((aFinish - 2)^) := TFake((aFinish - (1 + RSizeDiv))^);
                  TFake((aFinish - (1 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 3)^);
                  TFake((aFinish - 3)^) := TFake((aFinish - (2 + RSizeDiv))^);
                  TFake((aFinish - (2 + RSizeDiv))^) := v;
                end;
            end;
        end
      else
        if AlreadyPartitioned and PartialInsertionSort(aStart, PivotPos, c) and
           PartialInsertionSort(PivotPos + 1, aFinish, c) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost, c);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGRegularArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem;
  c: TLess): Boolean;
var
  Curr, Sift: PItem;
  Limit: SizeInt;
  v: TFake;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if c(Sift^, (Sift - 1)^) then
        begin
          v := TFake(Sift^);
          repeat
            TFake(Sift^) := TFake((Sift - 1)^);
            Dec(Sift);
          until (Sift = aStart) or not c(T(v), (Sift - 1)^);
          TFake(Sift^) := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGRegularArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem; c: TLess): PItem;
var
  Pivot: T;
  v: TFake;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until not c(Pivot, Last^);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if c(Pivot, First^) then
          break;
      end
  else
    repeat Inc(First) until c(Pivot, First^);

  while First < Last do
    begin
      v := TFake(First^);
      TFake(First^) := TFake(Last^);
      TFake(Last^) := v;
      repeat Dec(Last) until not c(Pivot, Last^);
      repeat Inc(First) until c(Pivot, First^);
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGRegularArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem; c: TLess);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True, c);
end;

{ TGRegularArrayHelper }

class function TGRegularArrayHelper.TryInsertSortA(A: PItem; L, R: SizeInt; c: TLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I], A[I-1]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGRegularArrayHelper.TryInsertSortD(A: PItem; L, R: SizeInt; c: TLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I-1], A[I]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(A[J-1], T(v));
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGRegularArrayHelper.CountRun(A: PItem; R: SizeInt; c: TLess; o: TSortOrder): SizeInt;
begin
  Result := 0;
  while (Result < R) and not (c(A[Result], A[Succ(Result)]) or c(A[Succ(Result)], A[Result])) do
    Inc(Result);
  if Result < R then
    if c(A[Result], A[Succ(Result)]) then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R, c);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, Result);
      end
    else                                    // descending
      begin
        Result := TryInsertSortD(A, Result, R, c);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, Result);
      end;
end;

class procedure TGRegularArrayHelper.InsertionSort(A: PItem; R: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class procedure TGRegularArrayHelper.UnguardInsertionSort(A: PItem; R: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class function TGRegularArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGRegularArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGRegularArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGRegularArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGRegularArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) or c(A[R], aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue, c);
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := R;
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) or c(aValue, A[R]) then
          exit;
        R := BiSearchLeftD(A, R, aValue, c);
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := R;
      end
    else           //constant
      if not(c(A[0], aValue) or c(aValue, A[0])) then
        Result := 0;
end;

class function TGRegularArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T;
  c: TLess): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if c(A[R], aValue) then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue, c);
      Result.InsertIndex := R;
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
            Result.FoundIndex := Pred(R);
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if c(aValue, A[R]) then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue, c);
        Result.InsertIndex := R;
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      begin
        if c(aValue, A[0]) then
          Result.InsertIndex := 0
        else
          begin
            Result.InsertIndex := Succ(R);
            if not c(A[0], aValue) then
              Result.FoundIndex := R;
          end;
      end;
end;

class procedure TGRegularArrayHelper.DoHeapSort(A: PItem; R: SizeInt; c: TLess);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(A[Curr]);
          while Next <= R do
            begin
              if(Next < R) and c(A[Next], A[Succ(Next)]) then
                Inc(Next);
              if not c(T(v), A[Next]) then
                break;
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(A[Curr]) := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(A[I]);
          TFake(A[I]) := TFake(A[0]);
          while Next < I do
            begin
              if(Succ(Next) < I) and c(A[Next], A[Succ(Next)]) then
                Inc(Next);
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and c(A[Next], T(v)) do
            begin
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(A[Curr]) := v;
        end;
    end
  else
    InsertionSort(A, R, c);
end;

class function TGRegularArrayHelper.QSplitR(A: PItem; R: SizeInt; c: TLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  Pivot := A[Succ(Random(Pred(R)))]; //shouldn't be first or last
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGRegularArrayHelper.DoQSort(A: PItem; R: SizeInt; c: TLess; aLeftmost: Boolean);
begin
  while R > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, R, c) do
      if Left <= R - Right then
        begin
          DoQSort(A, Left, c, aLeftmost);
          A := @A[Right];
          R -= Right;
          aLeftmost := False;
        end
      else
        begin
          DoQSort(@A[Right], R - Right, c, False);
          R := Left;
        end;
  if R > 0 then
    if aLeftmost then
      InsertionSort(A, R, c)
    else
      UnguardInsertionSort(A, R, c);
end;

class function TGRegularArrayHelper.MedianOf3(p1, p2, p3: PItem; c: TLess): PItem;
begin
  Result := p2;
  if c(p1^, Result^) then
    begin
      if c(p3^, Result^) then
        begin
          if c(p1^, p3^) then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if c(Result^, p3^) then
        begin
          if c(p3^, p1^) then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGRegularArrayHelper.QSplitMo9(A: PItem; R: SizeInt; c: TLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  if R > MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(A, @A[R shr 3], @A[R shr 2], c),
      MedianOf3(@A[R shr 1 - R shr 3], @A[R shr 1], @A[R shr 1 + R shr 3], c),
      MedianOf3(@A[R - R shr 2], @A[R - R shr 3], @A[R], c), c)^
  else
    Pivot := MedianOf3(A, @A[R shr 1], @A[R], c)^;
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGRegularArrayHelper.DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TLess; aLeftmost: Boolean);
begin
  if R > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, R, c) do
        begin
          if Left > 0 then
            DoIntroSort(A, Left, Pred(Ttl), c, aLeftmost);
          if Right < R then
            DoIntroSort(@A[Right], R - Right, Pred(Ttl), c, False);
        end
    else
      DoHeapSort(A, R, c)
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGRegularArrayHelper.DPQSplit(A: PItem; R: SizeInt; c: TLess): TSortSplit;
var
  v, Pivot1, Pivot2: TFake;
  pL, pR, I: SizeInt;
begin
  pL := Succ(Random(Pred(R shr 1)));
  //pR := Pred(R - Random(Pred(R shr 1)));
  pR := pL + R shr 1;

  if not c(A[pR], A[pL]) then
    begin
      Pivot1 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[0]);
      Pivot2 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[R]);
    end
  else
    begin
      Pivot2 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[R]);
      Pivot1 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[0]);
    end;

  pL := 1;
  I  := 1;
  pR := Pred(R);
  while I <= pR do
    begin
      v := TFake(A[I]);
      if c(T(v), T(Pivot1)) then
        begin
          TFake(A[I]) := TFake(A[pL]);
          TFake(A[pL]) := v;
          Inc(pL);
        end
      else
        if c(T(Pivot2), T(v)) then
          begin
            while (pR >= I) and c(T(Pivot2), A[pR]) do
              Dec(pR);
            if pR < I then
              break;
            if c(A[pR], T(Pivot1)) then
              begin
                TFake(A[I]) := TFake(A[pL]);
                TFake(A[pL]) := TFake(A[pR]);
                Inc(pL);
              end
            else
              TFake(A[I]) := TFake(A[pR]);
            TFake(A[pR]) := v;
            Dec(pR);
          end;
      Inc(I);
    end;
  TFake(A[0]) := TFake(A[pL - 1]);
  TFake(A[pL - 1]) := Pivot1;
  TFake(A[R]) := TFake(A[pR + 1]);
  TFake(A[pR + 1]) := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGRegularArrayHelper.DoDPQSort(A: PItem; R: SizeInt; c: TLess; aLeftmost: Boolean);
begin
  if R > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, R, c) do
      begin
        DoDPQSort(A, Left - 1, c, aLeftmost);
        DoDPQSort(@A[Right + 1], R - Right - 1, c, False);
        if c(A[Left], A[Right]) then
          DoDPQSort(@A[Left + 1], Right - Left - 2, c, False);
      end
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGRegularArrayHelper.QSelectR(A: PItem; R, N: SizeInt; c: TLess): T;
var
  v: TFake;
  Pivot: T;
  L, pL, pR: SizeInt;
begin
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until not c(A[pL], Pivot);
        repeat Dec(pR) until not c(Pivot, A[pR]);
        if pL >= pR then break;
        v := TFake(A[pL]);
        TFake(A[pL]) := TFake(A[pR]);
        TFake(A[pR]) := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and c(A[R], A[L]) then
    begin
      v := TFake(A[L]);
      TFake(A[L]) := TFake(A[R]);
      TFake(A[R]) := v;
    end;
  Result := A[N];
end;

class function TGRegularArrayHelper.SequentSearch(const A: array of T; const aValue: T;
  c: TLess): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if not(c(aValue, A[Result]) or c(A[Result], aValue)) then
      exit;
  Result := NULL_INDEX;
end;

class function TGRegularArrayHelper.BinarySearch(const A: array of T; const aValue: T;
  c: TLess): SizeInt;
begin
  Result := High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue, c);
end;

class function TGRegularArrayHelper.BinarySearchPos(const A: array of T; const aValue: T;
  c: TLess): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue, c)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGRegularArrayHelper.IndexOfMin(const A: array of T; c: TLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(A[I], v) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGRegularArrayHelper.IndexOfMax(const A: array of T; c: TLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(v, A[I]) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGRegularArrayHelper.GetMin(const A: array of T; c: TLess): TOptional;
var
  v: T;
begin
  if FindMin(A, v, c) then
    Result.Assign(v);
end;

class function TGRegularArrayHelper.GetMax(const A: array of T; c: TLess): TOptional;
var
  v: T;
begin
  if FindMax(A, v, c) then
    Result.Assign(v);
end;

class function TGRegularArrayHelper.FindMin(const A: array of T; out aValue: T; c: TLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(A[I], aValue) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGRegularArrayHelper.FindMax(const A: array of T; out aValue: T; c: TLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(aValue, A[I]) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGRegularArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T; c: TLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if c(aMax, A[I]) then
          aMax := A[I]
        else
          if c(A[I], aMin) then
            aMin := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGRegularArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T;
  c: TLess): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue, c));
  if N >= R then
    exit(FindMax(A, aValue, c));
  aValue := QSelectR(@A[0], R, N, c);
  Result := True;
end;

class function TGRegularArrayHelper.NthSmallest(var A: array of T; N: SizeInt; c: TLess): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v, c) then
    Result.Assign(v);
end;

class function TGRegularArrayHelper.FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T;
  c: TLess): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue, c);
end;

class function TGRegularArrayHelper.NthSmallestND(const A: array of T; N: SizeInt; c: TLess): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v, c) then
    Result.Assign(v);
end;

class function TGRegularArrayHelper.NextPermutation2Asc(var A: array of T; c: TLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[Succ(I)], A[I]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[I], A[J]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGRegularArrayHelper.NextPermutation2Desc(var A: array of T; c: TLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[I], A[Succ(I)]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[J], A[I]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGRegularArrayHelper.IsPermutation(const A, aPerm: array of T; c: TLess): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm, c) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA, c);
  Sort(LocPerm, c);
  Result := Same(LocA, LocPerm, c);
end;

class function TGRegularArrayHelper.IsNonDescending(const A: array of T; c: TLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[Succ(I)], A[I]) then
      exit(False);
  Result := True;
end;

class function TGRegularArrayHelper.IsStrictAscending(const A: array of T; c: TLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[Pred(I)], A[I]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGRegularArrayHelper.IsNonAscending(const A: array of T; c: TLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[I], A[Succ(I)]) then
      exit(False);
  Result := True;
end;

class function TGRegularArrayHelper.IsStrictDescending(const A: array of T; c: TLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[I], A[Pred(I)]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGRegularArrayHelper.InversionCount(var A: array of T; c: TLess): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and not c(A[J], A[I]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGRegularArrayHelper.InversionCountND(const A: array of T; c: TLess): Int64;
begin
  Result := InversionCount(CreateCopy(A), c);
end;

class function TGRegularArrayHelper.IsSubSequence(const A, aSeq: array of T; c: TLess): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if not (c(A[I], aSeq[J]) or c(A[I], aSeq[J])) then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGRegularArrayHelper.LisI(const A: array of T; c: TLess): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if c(A[TailIdx[M]], v) then
          L := Succ(M)
        else
          R := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if c(A[I], A[TailIdx[0]]) then
      TailIdx[0] := I
    else
      if c(A[TailIdx[Pred(Len)]], A[I]) then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGRegularArrayHelper.Lis(const A: array of T; c: TLess): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A, c);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGRegularArrayHelper.Same(const A, B: array of T; c: TLess): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if c(A[I], B[I]) or c(B[I], A[I]) then
        exit(False);
  Result := True;
end;

class procedure TGRegularArrayHelper.QuickSort(var A: array of T; c: TLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGRegularArrayHelper.IntroSort(var A: array of T; c: TLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGRegularArrayHelper.DualPivotQuickSort(var A: array of T; c: TLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoDPQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGRegularArrayHelper.PDQSort(var A: array of T; c: TLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1, c);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGRegularArrayHelper.MergeSort(var A: array of T; c: TLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if o = soAsc then
      TMergeSort.SortAsc(@A[0], R, c)
    else
      TMergeSort.SortDesc(@A[0], R, c);
end;

class procedure TGRegularArrayHelper.Sort(var A: array of T; c: TLess; o: TSortOrder);
begin
  PDQSort(A, c, o);
end;

class function TGRegularArrayHelper.Sorted(const A: array of T; c: TLess; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, c, o);
end;

class function TGRegularArrayHelper.SelectDistinct(const A: array of T; c: TLess): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A, c);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if not(c(Result[I], Result[J]) or c(Result[J], Result[I])) then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGDelegatedArrayHelper.TMergeSort }

procedure TGDelegatedArrayHelper.TMergeSort.Init(A: PItem; c: TOnLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGDelegatedArrayHelper.TMergeSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeAtA(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoA(Base, CountLo, CountHi)
  else
    MergeHiA(Base, CountLo, CountHi);
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeAtD(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoD(Base, CountLo, CountHi)
  else
    MergeHiD(Base, CountLo, CountHi);
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeLoA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TOnLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocA[pHi], LocB[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeLoD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TOnLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocB[pLo], LocA[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeHiA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TOnLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocB[pHi], LocA[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

procedure TGDelegatedArrayHelper.TMergeSort.MergeHiD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TOnLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocA[pLo], LocB[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

class procedure TGDelegatedArrayHelper.TMergeSort.InsertSortA(A: PItem; R, At: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGDelegatedArrayHelper.TMergeSort.InsertSortD(A: PItem; R, At: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGDelegatedArrayHelper.TMergeSort.CountRunAsc(A: PItem; R: SizeInt; c: TOnLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                       // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGDelegatedArrayHelper.TMergeSort.CountRunDesc(A: PItem; R: SizeInt; c: TOnLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                       // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGDelegatedArrayHelper.TMergeSort.SortAsc(A: PItem; R: SizeInt; c: TOnLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseA;
      until L > R;
      ms.ForceCollapseA;
    end;
end;

class procedure TGDelegatedArrayHelper.TMergeSort.SortDesc(A: PItem; R: SizeInt; c: TOnLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseD;
      until L > R;
      ms.ForceCollapseD;
    end;
end;

{ TGDelegatedArrayHelper.TBlockQSort }

class procedure TGDelegatedArrayHelper.TBlockQSort.Sort3(A, B, D: PItem; c: TOnLess);
var
  v: TFake;
begin
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
  if c(D^, B^) then
    begin
      v := TFake(B^);
      TFake(B^) := TFake(D^);
      TFake(D^) := v;
    end;
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
end;

function TGDelegatedArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem; c: TOnLess): TPart;
var
  Pivot: T;
  v: TFake;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not c(First^, Pivot);
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if c(Last^, Pivot) then
          break;
      end
  else
    repeat Dec(Last) until c(Last^, Pivot);

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := TFake(First^);
      TFake(First^) :=  TFake(Last^);
      TFake(Last^) := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not c(It^, Pivot));
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not c((It + 1)^, Pivot));
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not c((It + 2)^, Pivot));
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not c((It + 3)^, Pivot));
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not c((It + 4)^, Pivot));
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not c((It + 5)^, Pivot));
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not c((It + 6)^, Pivot));
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not c((It + 7)^, Pivot));
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt(c((It - 1)^, Pivot));
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt(c((It - 2)^, Pivot));
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt(c((It - 3)^, Pivot));
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt(c((It - 4)^, Pivot));
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt(c((It - 5)^, Pivot));
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt(c((It - 6)^, Pivot));
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt(c((It - 7)^, Pivot));
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt(c((It - 8)^, Pivot));
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not c(It^, Pivot));
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(c(It^, Pivot));
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := TFake((First + (OffsetsL + NumL)^)^);
          TFake((First + (OffsetsL + NumL)^)^) := TFake(Last^);
          TFake(Last^) := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := TFake((Last - (OffsetsR + NumR)^)^);
          TFake((Last - (OffsetsR + NumR)^)^) := TFake(First^);
          TFake(First^) := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGDelegatedArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt;
  aLeftMost: Boolean; c: TOnLess);
var
  PivotPos: PItem;
  v: TFake;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
  AlreadyPartitioned, HighlyUnbalanced: Boolean;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGDelegatedArrayHelper.InsertionSort(aStart, Pred(aFinish - aStart), c)
          else
            TGDelegatedArrayHelper.UnguardInsertionSort(aStart, Pred(aFinish - aStart), c);
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1, c);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2, c);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3, c);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1), c);
          v := TFake(aStart^);
          TFake(aStart^) := TFake((aStart + S2)^);
          TFake((aStart + S2)^) := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1, c);
      if (not aLeftMost) and not c((aStart - 1)^, aStart^) then
        begin
          aStart := PartitionLeft(aStart, aFinish, c) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish, c);

      PivotPos := PartResult.F1;
      AlreadyPartitioned := PartResult.F2;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      HighlyUnbalanced := (LSize < Size div 8) or (RSize < Size div 8);
      if HighlyUnbalanced then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGDelegatedArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart), c);
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := TFake(aStart^);
              TFake(aStart^) := TFake((aStart + LSizeDiv)^);
              TFake((aStart + LSizeDiv)^) := v;
              v := TFake((PivotPos - 1)^);
              TFake((PivotPos - 1)^) := TFake((PivotPos - LSizeDiv)^);
              TFake((PivotPos - LSizeDiv)^) := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((aStart + 1)^);
                  TFake((aStart + 1)^) := TFake((aStart + (LSizeDiv + 1))^);
                  TFake((aStart + (LSizeDiv + 1))^) := v;
                  v := TFake((aStart + 2)^);
                  TFake((aStart + 2)^) := TFake((aStart + (LSizeDiv + 2))^);
                  TFake((aStart + (LSizeDiv + 2))^) := v;
                  v := TFake((PivotPos - 2)^);
                  TFake((PivotPos - 2)^) := TFake((PivotPos - (LSizeDiv + 1))^);
                  TFake((PivotPos - (LSizeDiv + 1))^) := v;
                  v := TFake((PivotPos - 3)^);
                  TFake((PivotPos - 3)^) := TFake((PivotPos - (LSizeDiv + 2))^);
                  TFake((PivotPos - (LSizeDiv + 2))^) := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := TFake((PivotPos + 1)^);
              TFake((PivotPos + 1)^) := TFake((PivotPos + (1 + RSizeDiv))^);
              TFake((PivotPos + (1 + RSizeDiv))^) := v;
              v := TFake((aFinish - 1)^);
              TFake((aFinish - 1)^) := TFake((aFinish - RSizeDiv)^);
              TFake((aFinish - RSizeDiv)^) := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((PivotPos + 2)^);
                  TFake((PivotPos + 2)^) := TFake((PivotPos + (2 + RSizeDiv))^);
                  TFake((PivotPos + (2 + RSizeDiv))^) := v;
                  v := TFake((PivotPos + 3)^);
                  TFake((PivotPos + 3)^) := TFake((PivotPos + (3 + RSizeDiv))^);
                  TFake((PivotPos + (3 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 2)^);
                  TFake((aFinish - 2)^) := TFake((aFinish - (1 + RSizeDiv))^);
                  TFake((aFinish - (1 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 3)^);
                  TFake((aFinish - 3)^) := TFake((aFinish - (2 + RSizeDiv))^);
                  TFake((aFinish - (2 + RSizeDiv))^) := v;
                end;
            end;
        end
      else
        if AlreadyPartitioned and PartialInsertionSort(aStart, PivotPos, c) and
           PartialInsertionSort(PivotPos + 1, aFinish, c) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost, c);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGDelegatedArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem;
  c: TOnLess): Boolean;
var
  Curr, Sift: PItem;
  Limit: SizeInt;
  v: TFake;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if c(Sift^, (Sift - 1)^) then
        begin
          v := TFake(Sift^);
          repeat
            TFake(Sift^) := TFake((Sift - 1)^);
            Dec(Sift);
          until (Sift = aStart) or not c(T(v), (Sift - 1)^);
          TFake(Sift^) := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGDelegatedArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem;
  c: TOnLess): PItem;
var
  Pivot: T;
  v: TFake;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until not c(Pivot, Last^);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if c(Pivot, First^) then
          break;
      end
  else
    repeat Inc(First) until c(Pivot, First^);

  while First < Last do
    begin
      v := TFake(First^);
      TFake(First^) := TFake(Last^);
      TFake(Last^) := v;
      repeat Dec(Last) until not c(Pivot, Last^);
      repeat Inc(First) until c(Pivot, First^);
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGDelegatedArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem; c: TOnLess);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True, c);
end;

{ TGDelegatedArrayHelper }

class function TGDelegatedArrayHelper.TryInsertSortA(A: PItem; L, R: SizeInt; c: TOnLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I], A[I-1]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGDelegatedArrayHelper.TryInsertSortD(A: PItem; L, R: SizeInt; c: TOnLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I-1], A[I]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(A[J-1], T(v));
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGDelegatedArrayHelper.CountRun(A: PItem; R: SizeInt; c: TOnLess; o: TSortOrder): SizeInt;
begin
  Result := 0;
  while (Result < R) and not (c(A[Result], A[Succ(Result)]) or c(A[Succ(Result)], A[Result])) do
    Inc(Result);
  if Result < R then
    if c(A[Result], A[Succ(Result)]) then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R, c);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, Result);
      end
    else                                    // descending
      begin
        Result := TryInsertSortD(A, Result, R, c);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, Result);
      end;
end;

class procedure TGDelegatedArrayHelper.InsertionSort(A: PItem; R: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class procedure TGDelegatedArrayHelper.UnguardInsertionSort(A: PItem; R: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class function TGDelegatedArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGDelegatedArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGDelegatedArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGDelegatedArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGDelegatedArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) or c(A[R], aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue, c);
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := R;
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) or c(aValue, A[R]) then
          exit;
        R := BiSearchLeftD(A, R, aValue, c);
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := R;
      end
    else           //constant
      if not(c(A[0], aValue) or c(aValue, A[0])) then
        Result := 0;
end;

class function TGDelegatedArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T;
  c: TOnLess): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if c(A[R], aValue) then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue, c);
      Result.InsertIndex := R;
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
            Result.FoundIndex := Pred(R);
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if c(aValue, A[R]) then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue, c);
        Result.InsertIndex := R;
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      begin
        if c(aValue, A[0]) then
          Result.InsertIndex := 0
        else
          begin
            Result.InsertIndex := Succ(R);
            if not c(A[0], aValue) then
              Result.FoundIndex := R;
          end;
      end;
end;

class procedure TGDelegatedArrayHelper.DoHeapSort(A: PItem; R: SizeInt; c: TOnLess);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(A[Curr]);
          while Next <= R do
            begin
              if(Next < R) and c(A[Next], A[Succ(Next)])then
                Inc(Next);
              if not c(T(v), A[Next]) then
                break;
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(A[Curr]) := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(A[I]);
          TFake(A[I]) := TFake(A[0]);
          while Next < I do
            begin
              if(Succ(Next) < I) and c(A[Next], A[Succ(Next)]) then
                Inc(Next);
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and c(A[Next], T(v)) do
            begin
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(A[Curr]) := v;
        end;
    end
  else
    InsertionSort(A, R, c);
end;

class function TGDelegatedArrayHelper.QSplitR(A: PItem; R: SizeInt; c: TOnLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  Pivot := A[Succ(Random(Pred(R)))]; //shouldn't be first or last
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGDelegatedArrayHelper.DoQSort(A: PItem; R: SizeInt; c: TOnLess; aLeftmost: Boolean);
begin
  while R > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, R, c) do
      if Left <= R - Right then
        begin
          DoQSort(A, Left, c, aLeftmost);
          A := @A[Right];
          R -= Right;
          aLeftmost := False;
        end
      else
        begin
          DoQSort(@A[Right], R - Right, c, False);
          R := Left;
        end;
  if R > 0 then
    if aLeftmost then
      InsertionSort(A, R, c)
    else
      UnguardInsertionSort(A, R, c);
end;

class function TGDelegatedArrayHelper.MedianOf3(p1, p2, p3: PItem; c: TOnLess): PItem;
begin
  Result := p2;
  if c(p1^, Result^) then
    begin
      if c(p3^, Result^) then
        begin
          if c(p1^, p3^) then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if c(Result^, p3^) then
        begin
          if c(p3^, p1^) then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGDelegatedArrayHelper.QSplitMo9(A: PItem; R: SizeInt; c: TOnLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  if R > MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(A, @A[R shr 3], @A[R shr 2], c),
      MedianOf3(@A[R shr 1 - R shr 3], @A[R shr 1], @A[R shr 1 + R shr 3], c),
      MedianOf3(@A[R - R shr 2], @A[R - R shr 3], @A[R], c), c)^
  else
    Pivot := MedianOf3(A, @A[R shr 1], @A[R], c)^;
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGDelegatedArrayHelper.DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TOnLess;
  aLeftmost: Boolean);
begin
  if R > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, R, c) do
        begin
          if Left > 0 then
            DoIntroSort(A, Left, Pred(Ttl), c, aLeftmost);
          if Right < R then
            DoIntroSort(@A[Right], R - Right, Pred(Ttl), c, False);
        end
    else
      DoHeapSort(A, R, c)
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGDelegatedArrayHelper.DPQSplit(A: PItem; R: SizeInt; c: TOnLess): TSortSplit;
var
  v, Pivot1, Pivot2: TFake;
  pL, pR, I: SizeInt;
begin
  pL := Succ(Random(Pred(R shr 1)));
  //pR := Pred(R - Random(Pred(R shr 1)));
  pR := pL + R shr 1;

  if not c(A[pR], A[pL]) then
    begin
      Pivot1 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[0]);
      Pivot2 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[R]);
    end
  else
    begin
      Pivot2 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[R]);
      Pivot1 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[0]);
    end;

  pL := 1;
  I  := 1;
  pR := Pred(R);
  while I <= pR do
    begin
      v := TFake(A[I]);
      if c(T(v), T(Pivot1)) then
        begin
          TFake(A[I]) := TFake(A[pL]);
          TFake(A[pL]) := v;
          Inc(pL);
        end
      else
        if c(T(Pivot2), T(v)) then
          begin
            while (pR >= I) and c(T(Pivot2), A[pR]) do
              Dec(pR);
            if pR < I then
              break;
            if c(A[pR], T(Pivot1)) then
              begin
                TFake(A[I]) := TFake(A[pL]);
                TFake(A[pL]) := TFake(A[pR]);
                Inc(pL);
              end
            else
              TFake(A[I]) := TFake(A[pR]);
            TFake(A[pR]) := v;
            Dec(pR);
          end;
      Inc(I);
    end;
  TFake(A[0]) := TFake(A[pL - 1]);
  TFake(A[pL - 1]) := Pivot1;
  TFake(A[R]) := TFake(A[pR + 1]);
  TFake(A[pR + 1]) := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGDelegatedArrayHelper.DoDPQSort(A: PItem; R: SizeInt; c: TOnLess; aLeftmost: Boolean);
begin
  if R > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, R, c) do
      begin
        DoDPQSort(A, Left - 1, c, aLeftmost);
        DoDPQSort(@A[Right + 1], R - Right - 1, c, False);
        if c(A[Left], A[Right]) then
          DoDPQSort(@A[Left + 1], Right - Left - 2, c, False);
      end
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGDelegatedArrayHelper.QSelectR(A: PItem; R, N: SizeInt; c: TOnLess): T;
var
  v: TFake;
  Pivot: T;
  L, pL, pR: SizeInt;
begin
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until not c(A[pL], Pivot);
        repeat Dec(pR) until not c(Pivot, A[pR]);
        if pL >= pR then break;
        v := TFake(A[pL]);
        TFake(A[pL]) := TFake(A[pR]);
        TFake(A[pR]) := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and c(A[R], A[L]) then
    begin
      v := TFake(A[L]);
      TFake(A[L]) := TFake(A[R]);
      TFake(A[R]) := v;
    end;
  Result := A[N];
end;

class function TGDelegatedArrayHelper.SequentSearch(const A: array of T; const aValue: T;
  c: TOnLess): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if not(c(aValue, A[Result]) or c(A[Result], aValue)) then
      exit;
  Result := NULL_INDEX;
end;

class function TGDelegatedArrayHelper.BinarySearch(const A: array of T; const aValue: T;
  c: TOnLess): SizeInt;
begin
  Result := High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue, c);
end;

class function TGDelegatedArrayHelper.BinarySearchPos(const A: array of T; const aValue: T;
  c: TOnLess): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue, c)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGDelegatedArrayHelper.IndexOfMin(const A: array of T; c: TOnLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(A[I], v) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGDelegatedArrayHelper.IndexOfMax(const A: array of T; c: TOnLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(v, A[I]) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGDelegatedArrayHelper.GetMin(const A: array of T; c: TOnLess): TOptional;
var
  v: T;
begin
  if FindMin(A, v, c) then
    Result.Assign(v);
end;

class function TGDelegatedArrayHelper.GetMax(const A: array of T; c: TOnLess): TOptional;
var
  v: T;
begin
  if FindMax(A, v, c) then
    Result.Assign(v);
end;

class function TGDelegatedArrayHelper.FindMin(const A: array of T; out aValue: T; c: TOnLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(A[I], aValue) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGDelegatedArrayHelper.FindMax(const A: array of T; out aValue: T; c: TOnLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(aValue, A[I]) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGDelegatedArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T;
  c: TOnLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if c(aMax, A[I]) then
          aMax := A[I]
        else
          if c(A[I], aMin) then
            aMin := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGDelegatedArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T;
  c: TOnLess): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue, c));
  if N >= R then
    exit(FindMax(A, aValue, c));
  aValue := QSelectR(@A[0], R, N, c);
  Result := True;
end;

class function TGDelegatedArrayHelper.NthSmallest(var A: array of T; N: SizeInt; c: TOnLess): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v, c) then
    Result.Assign(v);
end;

class function TGDelegatedArrayHelper.FindNthSmallestND(const A: array of T;
  N: SizeInt; out aValue: T; c: TOnLess): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue, c);
end;

class function TGDelegatedArrayHelper.NthSmallestND(const A: array of T;N: SizeInt; c: TOnLess): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v, c) then
    Result.Assign(v);
end;

class function TGDelegatedArrayHelper.NextPermutation2Asc(var A: array of T; c: TOnLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[Succ(I)], A[I]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[I], A[J]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGDelegatedArrayHelper.NextPermutation2Desc(var A: array of T; c: TOnLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[I], A[Succ(I)]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[J], A[I]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGDelegatedArrayHelper.IsPermutation(const A, aPerm: array of T; c: TOnLess): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm, c) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA, c);
  Sort(LocPerm, c);
  Result := Same(LocA, LocPerm, c);
end;

class function TGDelegatedArrayHelper.IsNonDescending(const A: array of T; c: TOnLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[Succ(I)], A[I]) then
      exit(False);
  Result := True;
end;

class function TGDelegatedArrayHelper.IsStrictAscending(const A: array of T; c: TOnLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[Pred(I)], A[I]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGDelegatedArrayHelper.IsNonAscending(const A: array of T; c: TOnLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[I], A[Succ(I)]) then
      exit(False);
  Result := True;
end;

class function TGDelegatedArrayHelper.IsStrictDescending(const A: array of T; c: TOnLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[I], A[Pred(I)]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGDelegatedArrayHelper.InversionCount(var A: array of T; c: TOnLess): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and not c(A[J], A[I]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGDelegatedArrayHelper.InversionCountND(const A: array of T; c: TOnLess): Int64;
begin
  Result := InversionCount(CreateCopy(A), c);
end;

class function TGDelegatedArrayHelper.IsSubSequence(const A, aSeq: array of T; c: TOnLess): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if not (c(A[I], aSeq[J]) or c(A[I], aSeq[J])) then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGDelegatedArrayHelper.LisI(const A: array of T; c: TOnLess): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if c(A[TailIdx[M]], v) then
          L := Succ(M)
        else
          R := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if c(A[I], A[TailIdx[0]]) then
      TailIdx[0] := I
    else
      if c(A[TailIdx[Pred(Len)]], A[I]) then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGDelegatedArrayHelper.Lis(const A: array of T; c: TOnLess): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A, c);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGDelegatedArrayHelper.Same(const A, B: array of T; c: TOnLess): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if c(A[I], B[I]) or c(B[I], A[I]) then
        exit(False);
  Result := True;
end;

class procedure TGDelegatedArrayHelper.QuickSort(var A: array of T; c: TOnLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGDelegatedArrayHelper.IntroSort(var A: array of T; c: TOnLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGDelegatedArrayHelper.DualPivotQuickSort(var A: array of T; c: TOnLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoDPQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGDelegatedArrayHelper.PDQSort(var A: array of T; c: TOnLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1, c);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGDelegatedArrayHelper.MergeSort(var A: array of T; c: TOnLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if o = soAsc then
      TMergeSort.SortAsc(@A[0], R, c)
    else
      TMergeSort.SortDesc(@A[0], R, c);
end;

class procedure TGDelegatedArrayHelper.Sort(var A: array of T; c: TOnLess; o: TSortOrder);
begin
  PDQSort(A, c, o);
end;

class function TGDelegatedArrayHelper.Sorted(const A: array of T; c: TOnLess; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, c, o);
end;

class function TGDelegatedArrayHelper.SelectDistinct(const A: array of T; c: TOnLess): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A, c);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if not(c(Result[I], Result[J]) or c(Result[J], Result[I])) then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGNestedArrayHelper.TMergeSort }

procedure TGNestedArrayHelper.TMergeSort.Init(A: PItem; c: TNestLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGNestedArrayHelper.TMergeSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.MergeAtA(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoA(Base, CountLo, CountHi)
  else
    MergeHiA(Base, CountLo, CountHi);
end;

procedure TGNestedArrayHelper.TMergeSort.MergeAtD(aIndex: SizeInt);
var
  Base, CountLo, CountHi: SizeInt;
begin
  Base := FStack[aIndex].Base;
  CountLo := FStack[aIndex].Count;
  CountHi := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := CountLo + CountHi;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if CountLo <= CountHi then
    MergeLoD(Base, CountLo, CountHi)
  else
    MergeHiD(Base, CountLo, CountHi);
end;

procedure TGNestedArrayHelper.TMergeSort.MergeLoA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TNestLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocA[pHi], LocB[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.MergeLoD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in buffer)
  pHi,           // position in high part  (in data array)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TNestLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountLo);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From], LocB[0], CountLo * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From], LocB, CountLo);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := 0;
          pHi := From + CountLo;
          pDst := From;
          CountHi := Pred(From + CountLo + CountHi);
          repeat
            if not c(LocB[pLo], LocA[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocB[pLo]);
                Inc(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocA[pHi]);
                Inc(pHi);
              end;
            Inc(pDst);
          until (pLo >= CountLo) or (pHi > CountHi);
          if pLo < CountLo then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[pLo], LocA[pDst], (CountLo - pLo) * SizeOf(T));
            {$ELSE}
            CopyItems(@LocB[pLo], @LocA[pDst], CountLo - pLo);
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From + CountLo], LocA[From], CountHi * SizeOf(T));
          System.Move(LocB[0], LocA[From + CountHi], CountLo * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From + CountLo], @LocA[From], CountHi);
          CopyItems(LocB, @LocA[From + CountHi], CountLo);
          {$ENDIF}
        end;
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.MergeHiA(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TNestLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[From + CountLo], FData[Pred(From + CountLo)]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[Pred(From + CountLo + CountHi)], LocA[From]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocB[pHi], LocA[pLo]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

procedure TGNestedArrayHelper.TMergeSort.MergeHiD(From, CountLo, CountHi: SizeInt);
var
  pLo,           // position in low part   (in data array)
  pHi,           // position in high part  (in buffer)
  pDst: SizeInt; // current merge position (in data array)
  LocA: PItem;   // local pointer to data array
  LocB: PItem;   // local pointer to buffer
  c: TNestLess;
begin
  LocA := FData;
  c := FLess;
  if c(FData[Pred(From + CountLo)], FData[From + CountLo]) then
    begin
      LocB := EnsureBufferSize(CountHi);
      {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
      System.Move(LocA[From + CountLo], LocB[0], CountHi * SizeOf(T));
      {$ELSE}
      CopyItems(@LocA[From + CountLo], LocB, CountHi);
      {$ENDIF}
      if not c(LocA[From], LocA[Pred(From + CountLo + CountHi)]) then
        begin
          pLo := Pred(From + CountLo);
          pHi := CountHi - 1;
          pDst := Pred(From + CountLo + CountHi);
          repeat
            if c(LocA[pLo], LocB[pHi]) then
              begin
                TFake(LocA[pDst]) := TFake(LocA[pLo]);
                Dec(pLo);
              end
            else
              begin
                TFake(LocA[pDst]) := TFake(LocB[pHi]);
                Dec(pHi);
              end;
            Dec(pDst);
          until (pLo < From) or (pHi < 0);
          if pHi >= 0 then
            {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
            System.Move(LocB[0], LocA[From], Succ(pHi) * SizeOf(T));
            {$ELSE}
            CopyItems(LocB, @LocA[From], Succ(pHi));
            {$ENDIF}
        end
      else
        begin
          {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
          System.Move(LocA[From], LocA[From + CountHi], CountLo * SizeOf(T));
          System.Move(LocB[0], LocA[From], CountHi * SizeOf(T));
          {$ELSE}
          CopyItems(@LocA[From], @LocA[From + CountHi], CountLo);
          CopyItems(LocB, @LocA[From], CountHi);
          {$ENDIF}
        end;
    end;
end;

class procedure TGNestedArrayHelper.TMergeSort.InsertSortA(A: PItem; R, At: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGNestedArrayHelper.TMergeSort.InsertSortD(A: PItem; R, At: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGNestedArrayHelper.TMergeSort.CountRunAsc(A: PItem; R: SizeInt; c: TNestLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                       // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGNestedArrayHelper.TMergeSort.CountRunDesc(A: PItem; R: SizeInt; c: TNestLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                       // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGNestedArrayHelper.TMergeSort.SortAsc(A: PItem; R: SizeInt; c: TNestLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseA;
      until L > R;
      ms.ForceCollapseA;
    end;
end;

class procedure TGNestedArrayHelper.TMergeSort.SortDesc(A: PItem; R: SizeInt; c: TNestLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ms: TMergeSort;
begin
  if R > 0 then
    begin
      ms.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ms.PushRun(L, RunLen);
        L += RunLen;
        ms.CollapseD;
      until L > R;
      ms.ForceCollapseD;
    end;
end;

{ TGNestedArrayHelper.TBlockQSort }

class procedure TGNestedArrayHelper.TBlockQSort.Sort3(A, B, D: PItem; c: TNestLess);
var
  v: TFake;
begin
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
  if c(D^, B^) then
    begin
      v := TFake(B^);
      TFake(B^) := TFake(D^);
      TFake(D^) := v;
    end;
  if c(B^, A^) then
    begin
      v := TFake(A^);
      TFake(A^) := TFake(B^);
      TFake(B^) := v;
    end;
end;

function TGNestedArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem; c: TNestLess): TPart;
var
  Pivot: T;
  v: TFake;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not c(First^, Pivot);
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if c(Last^, Pivot) then
          break;
      end
  else
    repeat Dec(Last) until c(Last^, Pivot);

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := TFake(First^);
      TFake(First^) :=  TFake(Last^);
      TFake(Last^) := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not c(It^, Pivot));
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not c((It + 1)^, Pivot));
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not c((It + 2)^, Pivot));
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not c((It + 3)^, Pivot));
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not c((It + 4)^, Pivot));
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not c((It + 5)^, Pivot));
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not c((It + 6)^, Pivot));
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not c((It + 7)^, Pivot));
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt(c((It - 1)^, Pivot));
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt(c((It - 2)^, Pivot));
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt(c((It - 3)^, Pivot));
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt(c((It - 4)^, Pivot));
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt(c((It - 5)^, Pivot));
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt(c((It - 6)^, Pivot));
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt(c((It - 7)^, Pivot));
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt(c((It - 8)^, Pivot));
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not c(It^, Pivot));
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(c(It^, Pivot));
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := TFake((First + (OffsetsL + NumL)^)^);
          TFake((First + (OffsetsL + NumL)^)^) := TFake(Last^);
          TFake(Last^) := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := TFake((Last - (OffsetsR + NumR)^)^);
          TFake((Last - (OffsetsR + NumR)^)^) := TFake(First^);
          TFake(First^) := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGNestedArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt;
  aLeftMost: Boolean; c: TNestLess);
var
  PivotPos: PItem;
  v: TFake;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
  AlreadyPartitioned, HighlyUnbalanced: Boolean;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGNestedArrayHelper.InsertionSort(aStart, Pred(aFinish - aStart), c)
          else
            TGNestedArrayHelper.UnguardInsertionSort(aStart, Pred(aFinish - aStart), c);
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1, c);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2, c);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3, c);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1), c);
          v := TFake(aStart^);
          TFake(aStart^) := TFake((aStart + S2)^);
          TFake((aStart + S2)^) := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1, c);
      if (not aLeftMost) and not c((aStart - 1)^, aStart^) then
        begin
          aStart := PartitionLeft(aStart, aFinish, c) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish, c);

      PivotPos := PartResult.F1;
      AlreadyPartitioned := PartResult.F2;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      HighlyUnbalanced := (LSize < Size div 8) or (RSize < Size div 8);
      if HighlyUnbalanced then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGNestedArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart), c);
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := TFake(aStart^);
              TFake(aStart^) := TFake((aStart + LSizeDiv)^);
              TFake((aStart + LSizeDiv)^) := v;
              v := TFake((PivotPos - 1)^);
              TFake((PivotPos - 1)^) := TFake((PivotPos - LSizeDiv)^);
              TFake((PivotPos - LSizeDiv)^) := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((aStart + 1)^);
                  TFake((aStart + 1)^) := TFake((aStart + (LSizeDiv + 1))^);
                  TFake((aStart + (LSizeDiv + 1))^) := v;
                  v := TFake((aStart + 2)^);
                  TFake((aStart + 2)^) := TFake((aStart + (LSizeDiv + 2))^);
                  TFake((aStart + (LSizeDiv + 2))^) := v;
                  v := TFake((PivotPos - 2)^);
                  TFake((PivotPos - 2)^) := TFake((PivotPos - (LSizeDiv + 1))^);
                  TFake((PivotPos - (LSizeDiv + 1))^) := v;
                  v := TFake((PivotPos - 3)^);
                  TFake((PivotPos - 3)^) := TFake((PivotPos - (LSizeDiv + 2))^);
                  TFake((PivotPos - (LSizeDiv + 2))^) := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := TFake((PivotPos + 1)^);
              TFake((PivotPos + 1)^) := TFake((PivotPos + (1 + RSizeDiv))^);
              TFake((PivotPos + (1 + RSizeDiv))^) := v;
              v := TFake((aFinish - 1)^);
              TFake((aFinish - 1)^) := TFake((aFinish - RSizeDiv)^);
              TFake((aFinish - RSizeDiv)^) := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := TFake((PivotPos + 2)^);
                  TFake((PivotPos + 2)^) := TFake((PivotPos + (2 + RSizeDiv))^);
                  TFake((PivotPos + (2 + RSizeDiv))^) := v;
                  v := TFake((PivotPos + 3)^);
                  TFake((PivotPos + 3)^) := TFake((PivotPos + (3 + RSizeDiv))^);
                  TFake((PivotPos + (3 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 2)^);
                  TFake((aFinish - 2)^) := TFake((aFinish - (1 + RSizeDiv))^);
                  TFake((aFinish - (1 + RSizeDiv))^) := v;
                  v := TFake((aFinish - 3)^);
                  TFake((aFinish - 3)^) := TFake((aFinish - (2 + RSizeDiv))^);
                  TFake((aFinish - (2 + RSizeDiv))^) := v;
                end;
            end;
        end
      else
        if AlreadyPartitioned and PartialInsertionSort(aStart, PivotPos, c) and
           PartialInsertionSort(PivotPos + 1, aFinish, c) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost, c);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGNestedArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem;
  c: TNestLess): Boolean;
var
  Curr, Sift: PItem;
  Limit: SizeInt;
  v: TFake;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if c(Sift^, (Sift - 1)^) then
        begin
          v := TFake(Sift^);
          repeat
            TFake(Sift^) := TFake((Sift - 1)^);
            Dec(Sift);
          until (Sift = aStart) or not c(T(v), (Sift - 1)^);
          TFake(Sift^) := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGNestedArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem;
  c: TNestLess): PItem;
var
  Pivot: T;
  v: TFake;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until not c(Pivot, Last^);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if c(Pivot, First^) then
          break;
      end
  else
    repeat Inc(First) until c(Pivot, First^);

  while First < Last do
    begin
      v := TFake(First^);
      TFake(First^) := TFake(Last^);
      TFake(Last^) := v;
      repeat Dec(Last) until not c(Pivot, Last^);
      repeat Inc(First) until c(Pivot, First^);
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGNestedArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem; c: TNestLess);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True, c);
end;

{ TGNestedArrayHelper }

class function TGNestedArrayHelper.TryInsertSortA(A: PItem; L, R: SizeInt; c: TNestLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I], A[I-1]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGNestedArrayHelper.TryInsertSortD(A: PItem; L, R: SizeInt; c: TNestLess): SizeInt;
var
  I, J, Dist: SizeInt;
  v: TFake;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if c(A[I-1], A[I]) then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(A[J-1], T(v));
        TFake(A[J]) := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGNestedArrayHelper.CountRun(A: PItem; R: SizeInt; c: TNestLess; o: TSortOrder): SizeInt;
begin
  Result := 0;
  while (Result < R) and not (c(A[Result], A[Succ(Result)]) or c(A[Succ(Result)], A[Result])) do
    Inc(Result);
  if Result < R then
    if c(A[Result], A[Succ(Result)]) then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R, c);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, Result);
      end
    else                                    // descending
      begin
        Result := TryInsertSortD(A, Result, R, c);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, Result);
      end;
end;

class procedure TGNestedArrayHelper.InsertionSort(A: PItem; R: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until (J = 0) or not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class procedure TGNestedArrayHelper.UnguardInsertionSort(A: PItem; R: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  for I := 1 to R do
    if c(A[I], A[I-1]) then
      begin
        J := I;
        v := TFake(A[I]);
        repeat
          TFake(A[J]) := TFake(A[J-1]);
          Dec(J);
        until not c(T(v), A[J-1]);
        TFake(A[J]) := v;
      end;
end;

class function TGNestedArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGNestedArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGNestedArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(aValue, A[M]) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGNestedArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if c(A[M], aValue) then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGNestedArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) or c(A[R], aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue, c);
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := R;
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) or c(aValue, A[R]) then
          exit;
        R := BiSearchLeftD(A, R, aValue, c);
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := R;
      end
    else           //constant
      if not(c(A[0], aValue) or c(aValue, A[0])) then
        Result := 0;
end;

class function TGNestedArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T;
  c: TNestLess): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if c(A[0], A[R]) then  //ascending
    begin
      if c(aValue, A[0]) then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if c(A[R], aValue) then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue, c);
      Result.InsertIndex := R;
      if not(c(A[R], aValue) or c(aValue, A[R])) then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
            Result.FoundIndex := Pred(R);
    end
  else
    if c(A[R], A[0]) then  //descending
      begin
        if c(A[0], aValue) then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if c(aValue, A[R]) then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue, c);
        Result.InsertIndex := R;
        if not(c(A[R], aValue) or c(aValue, A[R])) then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if not(c(A[Pred(R)], aValue) or c(aValue, A[Pred(R)])) then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      begin
        if c(aValue, A[0]) then
          Result.InsertIndex := 0
        else
          begin
            Result.InsertIndex := Succ(R);
            if not c(A[0], aValue) then
              Result.FoundIndex := R;
          end;
      end;
end;

class procedure TGNestedArrayHelper.DoHeapSort(A: PItem; R: SizeInt; c: TNestLess);
var
  I, Curr, Next: SizeInt;
  v: TFake;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := TFake(A[Curr]);
          while Next <= R do
            begin
              if(Next < R) and c(A[Next], A[Succ(Next)]) then
                Inc(Next);
              if not c(T(v), A[Next]) then
                break;
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          TFake(A[Curr]) := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := TFake(A[I]);
          TFake(A[I]) := TFake(A[0]);
          while Next < I do
            begin
              if(Succ(Next) < I) and c(A[Next], A[Succ(Next)]) then
                Inc(Next);
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and c(A[Next], T(v)) do
            begin
              TFake(A[Curr]) := TFake(A[Next]);
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          TFake(A[Curr]) := v;
        end;
    end
  else
    InsertionSort(A, R, c);
end;

class function TGNestedArrayHelper.QSplitR(A: PItem; R: SizeInt; c: TNestLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  Pivot := A[Succ(Random(Pred(R)))]; //shouldn't be first or last
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGNestedArrayHelper.DoQSort(A: PItem; R: SizeInt; c: TNestLess; aLeftmost: Boolean);
begin
  while R > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, R, c) do
      if Left <= R - Right then
        begin
          DoQSort(A, Left, c, aLeftmost);
          A := @A[Right];
          R -= Right;
          aLeftmost := False;
        end
      else
        begin
          DoQSort(@A[Right], R - Right, c, False);
          R := Left;
        end;
  if R > 0 then
    if aLeftmost then
      InsertionSort(A, R, c)
    else
      UnguardInsertionSort(A, R, c);
end;

class function TGNestedArrayHelper.MedianOf3(p1, p2, p3: PItem; c: TNestLess): PItem;
begin
  Result := p2;
  if c(p1^, Result^) then
    begin
      if c(p3^, Result^) then
        begin
          if c(p1^, p3^) then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if c(Result^, p3^) then
        begin
          if c(p3^, p1^) then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGNestedArrayHelper.QSplitMo9(A: PItem; R: SizeInt; c: TNestLess): TSortSplit;
var
  Pivot: T;
  v: TFake;
  pL, pR: SizeInt;
begin
  if R > MEDIAN_OF9_CUTOFF then
    Pivot := MedianOf3(
      MedianOf3(A, @A[R shr 3], @A[R shr 2], c),
      MedianOf3(@A[R shr 1 - R shr 3], @A[R shr 1], @A[R shr 1 + R shr 3], c),
      MedianOf3(@A[R - R shr 2], @A[R - R shr 3], @A[R], c), c)^
  else
    Pivot := MedianOf3(A, @A[R shr 1], @A[R], c)^;
  pL := -1;
  pR := Succ(R);
  repeat
    repeat Inc(pL) until not c(A[pL], Pivot);
    repeat Dec(pR) until not c(Pivot, A[pR]);
    if pL > pR then break;
    v := TFake(A[pL]);
    TFake(A[pL]) := TFake(A[pR]);
    TFake(A[pR]) := v;
  until False;
  Result.Left := pR;
  Result.Right := pL;
end;

class procedure TGNestedArrayHelper.DoIntroSort(A: PItem; R, Ttl: SizeInt; c: TNestLess;
  aLeftmost: Boolean);
begin
  if R > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, R, c) do
        begin
          if Left > 0 then
            DoIntroSort(A, Left, Pred(Ttl), c, aLeftmost);
          if Right < R then
            DoIntroSort(@A[Right], R - Right, Pred(Ttl), c, False);
        end
    else
      DoHeapSort(A, R, c)
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGNestedArrayHelper.DPQSplit(A: PItem; R: SizeInt; c: TNestLess): TSortSplit;
var
  v, Pivot1, Pivot2: TFake;
  pL, pR, I: SizeInt;
begin
  pL := Succ(Random(Pred(R shr 1)));
  //pR := Pred(R - Random(Pred(R shr 1)));
  pR := pL + R shr 1;

  if not c(A[pR], A[pL]) then
    begin
      Pivot1 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[0]);
      Pivot2 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[R]);
    end
  else
    begin
      Pivot2 := TFake(A[pL]);
      TFake(A[pL]) := TFake(A[R]);
      Pivot1 := TFake(A[pR]);
      TFake(A[pR]) := TFake(A[0]);
    end;

  pL := 1;
  I  := 1;
  pR := Pred(R);
  while I <= pR do
    begin
      v := TFake(A[I]);
      if c(T(v), T(Pivot1)) then
        begin
          TFake(A[I]) := TFake(A[pL]);
          TFake(A[pL]) := v;
          Inc(pL);
        end
      else
        if c(T(Pivot2), T(v)) then
          begin
            while (pR >= I) and c(T(Pivot2), A[pR]) do
              Dec(pR);
            if pR < I then
              break;
            if c(A[pR], T(Pivot1)) then
              begin
                TFake(A[I]) := TFake(A[pL]);
                TFake(A[pL]) := TFake(A[pR]);
                Inc(pL);
              end
            else
              TFake(A[I]) := TFake(A[pR]);
            TFake(A[pR]) := v;
            Dec(pR);
          end;
      Inc(I);
    end;
  TFake(A[0]) := TFake(A[pL - 1]);
  TFake(A[pL - 1]) := Pivot1;
  TFake(A[R]) := TFake(A[pR + 1]);
  TFake(A[pR + 1]) := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGNestedArrayHelper.DoDPQSort(A: PItem; R: SizeInt; c: TNestLess; aLeftmost: Boolean);
begin
  if R > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, R, c) do
      begin
        DoDPQSort(A, Left - 1, c, aLeftmost);
        DoDPQSort(@A[Right + 1], R - Right - 1, c, False);
        if c(A[Left], A[Right]) then
          DoDPQSort(@A[Left + 1], Right - Left - 2, c, False);
      end
  else
    if R > 0 then
      if aLeftmost then
        InsertionSort(A, R, c)
      else
        UnguardInsertionSort(A, R, c);
end;

class function TGNestedArrayHelper.QSelectR(A: PItem; R, N: SizeInt; c: TNestLess): T;
var
  v: TFake;
  Pivot: T;
  L, pL, pR: SizeInt;
begin
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until not c(A[pL], Pivot);
        repeat Dec(pR) until not c(Pivot, A[pR]);
        if pL >= pR then break;
        v := TFake(A[pL]);
        TFake(A[pL]) := TFake(A[pR]);
        TFake(A[pR]) := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and c(A[R], A[L]) then
    begin
      v := TFake(A[L]);
      TFake(A[L]) := TFake(A[R]);
      TFake(A[R]) := v;
    end;
  Result := A[N];
end;

class function TGNestedArrayHelper.SequentSearch(const A: array of T; const aValue: T;
  c: TNestLess): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if not(c(aValue, A[Result]) or c(A[Result], aValue)) then
      exit;
  Result := NULL_INDEX;
end;

class function TGNestedArrayHelper.BinarySearch(const A: array of T; const aValue: T;
  c: TNestLess): SizeInt;
begin
  Result := High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue, c);
end;

class function TGNestedArrayHelper.BinarySearchPos(const A: array of T; const aValue: T;
  c: TNestLess): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue, c)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGNestedArrayHelper.IndexOfMin(const A: array of T; c: TNestLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(A[I], v) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGNestedArrayHelper.IndexOfMax(const A: array of T; c: TNestLess): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if c(v, A[I]) then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGNestedArrayHelper.GetMin(const A: array of T; c: TNestLess): TOptional;
var
  v: T;
begin
  if FindMin(A, v, c) then
    Result.Assign(v);
end;

class function TGNestedArrayHelper.GetMax(const A: array of T; c: TNestLess): TOptional;
var
  v: T;
begin
  if FindMax(A, v, c) then
    Result.Assign(v);
end;

class function TGNestedArrayHelper.FindMin(const A: array of T; out aValue: T; c: TNestLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(A[I], aValue) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGNestedArrayHelper.FindMax(const A: array of T; out aValue: T; c: TNestLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aValue := A[0];
      for I := 1 to R do
        if c(aValue, A[I]) then
          aValue := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGNestedArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T;
  c: TNestLess): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if c(aMax, A[I]) then
          aMax := A[I]
        else
          if c(A[I], aMin) then
            aMin := A[I];
      exit(True);
    end;
  Result := False;
end;

class function TGNestedArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T;
  c: TNestLess): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue, c));
  if N >= R then
    exit(FindMax(A, aValue, c));
  aValue := QSelectR(@A[0], R, N, c);
  Result := True;
end;

class function TGNestedArrayHelper.NthSmallest(var A: array of T; N: SizeInt; c: TNestLess): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v, c) then
    Result.Assign(v);
end;

class function TGNestedArrayHelper.FindNthSmallestND(const A: array of T;
  N: SizeInt; out aValue: T; c: TNestLess): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue, c);
end;

class function TGNestedArrayHelper.NthSmallestND(const A: array of T;N: SizeInt; c: TNestLess): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v, c) then
    Result.Assign(v);
end;

class function TGNestedArrayHelper.NextPermutation2Asc(var A: array of T; c: TNestLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[Succ(I)], A[I]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[I], A[J]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGNestedArrayHelper.NextPermutation2Desc(var A: array of T; c: TNestLess): Boolean;
var
  I, J, R: SizeInt;
  v: TFake;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if c(A[I], A[Succ(I)]) then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if c(A[J], A[I]) then
      begin
        v := TFake(A[I]);
        TFake(A[I]) := TFake(A[J]);
        TFake(A[J]) := v;
        break;
      end;
  DoReverse(@A[Succ(J)], R - Succ(J));
  Result := True;
end;

class function TGNestedArrayHelper.IsPermutation(const A, aPerm: array of T; c: TNestLess): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm, c) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA, c);
  Sort(LocPerm, c);
  Result := Same(LocA, LocPerm, c);
end;

class function TGNestedArrayHelper.IsNonDescending(const A: array of T; c: TNestLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[Succ(I)], A[I]) then
      exit(False);
  Result := True;
end;

class function TGNestedArrayHelper.IsStrictAscending(const A: array of T; c: TNestLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[Pred(I)], A[I]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGNestedArrayHelper.IsNonAscending(const A: array of T; c: TNestLess): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if c(A[I], A[Succ(I)]) then
      exit(False);
  Result := True;
end;

class function TGNestedArrayHelper.IsStrictDescending(const A: array of T; c: TNestLess): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if not c(A[I], A[Pred(I)]) then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGNestedArrayHelper.InversionCount(var A: array of T; c: TNestLess): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and not c(A[J], A[I]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGNestedArrayHelper.InversionCountND(const A: array of T; c: TNestLess): Int64;
begin
  Result := InversionCount(CreateCopy(A), c);
end;

class function TGNestedArrayHelper.IsSubSequence(const A, aSeq: array of T; c: TNestLess): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if not (c(A[I], aSeq[J]) or c(A[I], aSeq[J])) then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGNestedArrayHelper.LisI(const A: array of T; c: TNestLess): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if c(A[TailIdx[M]], v) then
          L := Succ(M)
        else
          R := M;
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if c(A[I], A[TailIdx[0]]) then
      TailIdx[0] := I
    else
      if c(A[TailIdx[Pred(Len)]], A[I]) then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGNestedArrayHelper.Lis(const A: array of T; c: TNestLess): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A, c);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGNestedArrayHelper.Same(const A, B: array of T; c: TNestLess): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if c(A[I], B[I]) or c(B[I], A[I]) then
        exit(False);
  Result := True;
end;

class procedure TGNestedArrayHelper.QuickSort(var A: array of T; c: TNestLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGNestedArrayHelper.IntroSort(var A: array of T; c: TNestLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGNestedArrayHelper.DualPivotQuickSort(var A: array of T; c: TNestLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      DoDPQSort(@A[0], R, c, True);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGNestedArrayHelper.PDQSort(var A: array of T; c: TNestLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(@A[0], R, c, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1, c);
      if o = soDesc then
        Reverse(A);
    end;
end;

class procedure TGNestedArrayHelper.MergeSort(var A: array of T; c: TNestLess; o: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if o = soAsc then
      TMergeSort.SortAsc(@A[0], R, c)
    else
      TMergeSort.SortDesc(@A[0], R, c);
end;

class procedure TGNestedArrayHelper.Sort(var A: array of T; c: TNestLess; o: TSortOrder);
begin
  PDQSort(A, c, o);
end;

class function TGNestedArrayHelper.Sorted(const A: array of T; c: TNestLess; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, c, o);
end;

class function TGNestedArrayHelper.SelectDistinct(const A: array of T; c: TNestLess): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A, c);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if not(c(Result[I], Result[J]) or c(Result[J], Result[I])) then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGSimpleArrayHelper.TBlockQSort }

class procedure TGSimpleArrayHelper.TBlockQSort.Sort3(A, B, C: PItem);
var
  v: T;
begin
  if B^ < A^ then
    begin
      v := A^;
      A^ := B^;
      B^ := v;
    end;
  if C^ < B^ then
    begin
      v := B^;
      B^ := C^;
      C^ := v;
    end;
  if B^ < A^ then
    begin
      v := A^;
      A^ := B^;
      B^ := v;
    end;
end;

function TGSimpleArrayHelper.TBlockQSort.PartitionRight(aStart, aFinish: PItem): TPart;
var
  Pivot, v: T;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until First^ >= Pivot;
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if Last^ < Pivot then
          break;
      end
  else
    repeat Dec(Last) until Last^ < Pivot;

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := First^;
      First^ :=  Last^;
      Last^ := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(It^ >= Pivot);
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt((It + 1)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt((It + 2)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt((It + 3)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt((It + 4)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt((It + 5)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt((It + 6)^ >= Pivot);
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt((It + 7)^ >= Pivot);
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt((It - 1)^ < Pivot);
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt((It - 2)^ < Pivot);
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt((It - 3)^ < Pivot);
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt((It - 4)^ < Pivot);
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt((It - 5)^ < Pivot);
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt((It - 6)^ < Pivot);
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt((It - 7)^ < Pivot);
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt((It - 8)^ < Pivot);
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(It^ >= Pivot);
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(It^ < Pivot);
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := (First + (OffsetsL + NumL)^)^;
          (First + (OffsetsL + NumL)^)^ := Last^;
          Last^ := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := (Last - (OffsetsR + NumR)^)^;
          (Last - (OffsetsR + NumR)^)^ := First^;
          First^ := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TGSimpleArrayHelper.TBlockQSort.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt;
  aLeftMost: Boolean);
var
  PivotPos: PItem;
  v: T;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            TGSimpleArrayHelper.InsertionSort(aStart^, 0, Pred(aFinish - aStart))
          else
            TGSimpleArrayHelper.UnguardInsertionSort(aStart^, 0, Pred(aFinish - aStart));
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1));
          v := aStart^;
          aStart^ := (aStart + S2)^;
          (aStart + S2)^ := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1);
      if (not aLeftMost) and ((aStart - 1)^ >= aStart^) then
        begin
          aStart := PartitionLeft(aStart, aFinish) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish);

      PivotPos := PartResult.F1;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      if (LSize < Size div 8) or (RSize < Size div 8) then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              TGSimpleArrayHelper.DoHeapSort(aStart, Pred(aFinish - aStart));
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := aStart^;
              aStart^ := (aStart + LSizeDiv)^;
              (aStart + LSizeDiv)^ := v;
              v := (PivotPos - 1)^;
              (PivotPos - 1)^ := (PivotPos - LSizeDiv)^;
              (PivotPos - LSizeDiv)^ := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := (aStart + 1)^;
                  (aStart + 1)^ := (aStart + (LSizeDiv + 1))^;
                  (aStart + (LSizeDiv + 1))^ := v;
                  v := (aStart + 2)^;
                  (aStart + 2)^ := (aStart + (LSizeDiv + 2))^;
                  (aStart + (LSizeDiv + 2))^ := v;
                  v := (PivotPos - 2)^;
                  (PivotPos - 2)^ := (PivotPos - (LSizeDiv + 1))^;
                  (PivotPos - (LSizeDiv + 1))^ := v;
                  v := (PivotPos - 3)^;
                  (PivotPos - 3)^ := (PivotPos - (LSizeDiv + 2))^;
                  (PivotPos - (LSizeDiv + 2))^ := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := (PivotPos + 1)^;
              (PivotPos + 1)^ := (PivotPos + (1 + RSizeDiv))^;
              (PivotPos + (1 + RSizeDiv))^ := v;
              v := (aFinish - 1)^;
              (aFinish - 1)^ := (aFinish - RSizeDiv)^;
              (aFinish - RSizeDiv)^ := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := (PivotPos + 2)^;
                  (PivotPos + 2)^ := (PivotPos + (2 + RSizeDiv))^;
                  (PivotPos + (2 + RSizeDiv))^ := v;
                  v := (PivotPos + 3)^;
                  (PivotPos + 3)^ := (PivotPos + (3 + RSizeDiv))^;
                  (PivotPos + (3 + RSizeDiv))^ := v;
                  v := (aFinish - 2)^;
                  (aFinish - 2)^ := (aFinish - (1 + RSizeDiv))^;
                  (aFinish - (1 + RSizeDiv))^ := v;
                  v := (aFinish - 3)^;
                  (aFinish - 3)^ := (aFinish - (2 + RSizeDiv))^;
                  (aFinish - (2 + RSizeDiv))^ := v;
                end;
            end;
        end
      else
        if PartResult.F2 and PartialInsertionSort(aStart, PivotPos) and
           PartialInsertionSort(PivotPos + 1, aFinish) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

class function TGSimpleArrayHelper.TBlockQSort.PartialInsertionSort(aStart, aFinish: PItem): Boolean;
var
  Curr, Sift: PItem;
  Limit: SizeInt;
  v: T;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if Sift^ < (Sift - 1)^ then
        begin
          v := Sift^;
          repeat
            Sift^ := (Sift - 1)^;
            Dec(Sift);
          until (Sift = aStart) or (v >= (Sift - 1)^);
          Sift^ := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

class function TGSimpleArrayHelper.TBlockQSort.PartitionLeft(aStart, aFinish: PItem): PItem;
var
  Pivot, v: T;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until Pivot >= Last^;
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if Pivot < First^ then
          break;
      end
  else
    repeat Inc(First) until Pivot < First^;

  while First < Last do
    begin
      v := First^;
      First^ := Last^;
      Last^ := v;
      repeat Dec(Last) until Pivot >= Last^;
      repeat Inc(First) until Pivot < First^;
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;

class procedure TGSimpleArrayHelper.TBlockQSort.SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
  aNum: SizeInt; aUseSwaps: Boolean);
var
  L, R: PItem;
  I: SizeInt;
  v: T;
begin
  if aUseSwaps then
    for I := 0 to Pred(aNum) do
      begin
        v := (aFirst + SizeInt(aOffsetsL[I]))^;
        (aFirst + SizeInt(aOffsetsL[I]))^ := (aLast - SizeInt(aOffsetsR[I]))^;
        (aLast - SizeInt(aOffsetsR[I]))^ := v;
      end
  else
    if aNum > 0 then
      begin
        L := aFirst + SizeInt(aOffsetsL[0]);
        R := aLast - SizeInt(aOffsetsR[0]);
        v := L^;
        L^ := R^;
        for I := 1 to Pred(aNum) do
          begin
            L := aFirst + SizeInt(aOffsetsL[I]);
            R^ := L^;
            R := aLast - SizeInt(aOffsetsR[I]);
            L^ := R^;
          end;
        R^ := v;
      end;
end;

class procedure TGSimpleArrayHelper.TBlockQSort.PDQSort(aStart, aFinish: PItem);
var
  Sorter: TBlockQSort;
begin
  {%H-}Sorter.DoPDQSort(aStart, aFinish, Succ(LGUtils.NSB(aFinish - aStart)), True);
end;

{ TGSimpleArrayHelper }

class function TGSimpleArrayHelper.TryInsertSortA(var A: array of T; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: T;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I] < A[I-1] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = 0) or (v >= A[J-1]);
        A[J] := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGSimpleArrayHelper.TryInsertSortD(var A: array of T; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: T;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I-1] < A[I] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = 0) or (v <= A[J-1]);
        A[J] := v;
        Dist += I - J;
      end;
   Result := R;
end;

class function TGSimpleArrayHelper.CountRun(var A: array of T; L, R: SizeInt; o: TSortOrder): SizeInt;
begin
  Result := L;
  while (Result < R) and (A[Result] = A[Succ(Result)]) do
    Inc(Result);
  if Result < R then
    if A[Result] < A[Succ(Result)] then   // ascending
      begin
        Result := TryInsertSortA(A, Result, R);
        if (Result = R) and (o = soDesc) then
          DoReverse(A, L, R);
      end
    else                                  // descending
      begin
        Result := TryInsertSortD(A, Result, R);
        if (Result = R) and (o = soAsc) then
          DoReverse(A, L, R);
      end;
end;

class procedure TGSimpleArrayHelper.InsertionSort(var A: array of T; L, R: SizeInt);
var
  I, J: SizeInt;
  v: T;
begin
  for I := L + 1 to R do
    if A[I] < A[I-1] then
      begin
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = L) or (v >= A[J-1]);
        A[J] := v;
      end;
end;

class procedure TGSimpleArrayHelper.UnguardInsertionSort(var A: array of T; L, R: SizeInt);
var
  I, J: SizeInt;
  v: T;
begin
  for I := L + 1 to R do
    if A[I] < A[I-1] then
      begin
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until v >= A[J-1];
        A[J] := v;
      end;
end;

class function TGSimpleArrayHelper.BiSearchLeftA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] < aValue then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGSimpleArrayHelper.BiSearchLeftD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] > aValue then
        L := Succ(M)
      else
        R := M;
    end;
  Result := R;
end;

class function TGSimpleArrayHelper.BiSearchRightA(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] > aValue then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGSimpleArrayHelper.BiSearchRightD(A: PItem; R: SizeInt; const aValue: T): SizeInt;
var
  L, M: SizeInt;
begin
  L := 0;
  while L < R do
    begin
      {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
      if A[M] < aValue then
        R := M
      else
        L := Succ(M);
    end;
  Result := R;
end;

class function TGSimpleArrayHelper.DoBinSearch(A: PItem; R: SizeInt; const aValue: T): SizeInt;
begin
  //here R must be >= 0;
  Result := NULL_INDEX;
  if A[R] > A[0] then  //ascending
    begin
      if (A[0] > aValue) or (A[R] < aValue) then
        exit;
      R := BiSearchLeftA(A, R, aValue);
      if A[R] = aValue then
        Result := R;
    end
  else
    if A[R] < A[0] then  //descending
      begin
        if (A[0] < aValue) or (A[R] > aValue) then
          exit;
        R := BiSearchLeftD(A, R, aValue);
        if A[R] = aValue then
          Result := R;
      end
    else              //constant
      if A[0] = aValue then
        Result := 0;
end;

class function TGSimpleArrayHelper.DoBinSearchPos(A: PItem; R: SizeInt; const aValue: T): TSearchResult;
begin
  //here R must be >= 0;
  Result.FoundIndex := NULL_INDEX;
  if A[R] > A[0] then  //ascending
    begin
      if A[0] > aValue then
        begin
          Result.InsertIndex := 0;
          exit;
        end
      else
        if A[R] < aValue then
          begin
            Result.InsertIndex := Succ(R);
            exit;
          end;
      R := BiSearchRightA(A, R, aValue);
      Result.InsertIndex := R;
      if A[R] = aValue then
        Result := TSearchResult.Create(R, Succ(R))
      else
        if R > 0 then
          if A[Pred(R)] = aValue then
            Result.FoundIndex := Pred(R);
    end
  else
    if A[R] < A[0] then  //descending
      begin
        if A[0] < aValue then
          begin
            Result.InsertIndex := 0;
            exit;
          end
        else
          if A[R] > aValue then
            begin
              Result.InsertIndex := Succ(R);
              exit;
            end;
        R := BiSearchRightD(A, R, aValue);
        Result.InsertIndex := R;
        if A[R] = aValue then
          Result := TSearchResult.Create(R, Succ(R))
        else
          if R > 0 then
            if A[Pred(R)] = aValue then
              Result.FoundIndex := Pred(R);
      end
    else           //constant
      if A[0] > aValue then
        Result.InsertIndex := 0
      else
        begin
          Result.InsertIndex := Succ(R);
          if A[0] = aValue then
            Result.FoundIndex := R;
        end;
end;

class procedure TGSimpleArrayHelper.DoHeapSort(A: PItem; R: SizeInt);
var
  I, Curr, Next: SizeInt;
  v: T;
begin
  if R > 0 then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := A[Curr];
          while Next <= R do
            begin
              if(Next < R) and (A[Next] < A[Succ(Next)])then
                Inc(Next);
              if v >= A[Next] then
                break;
              A[Curr] := A[Next];
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          A[Curr] := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := A[I];
          A[I] := A[0];
          while Next < I do
            begin
              if(Succ(Next) < I) and (A[Next] < A[Succ(Next)]) then
                Inc(Next);
              A[Curr] := A[Next];
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and (v > A[Next]) do
            begin
              A[Curr] := A[Next];
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          A[Curr] := v;
        end;
    end;
end;

class function TGSimpleArrayHelper.QSplitR(var A: array of T; L, R: SizeInt): TSortSplit;
var
  v, Pivot: T;
begin
  Pivot := A[Succ(L + Random(Pred(R - L)))]; //shouldn't be first or last
  Dec(L);
  Inc(R);
  repeat
    repeat Inc(L); until A[L] >= Pivot;
    repeat Dec(R); until A[R] <= Pivot;
    //if L > R then
    //  break;
    v := A[L];
    A[L] := A[R];
    A[R] := v;
  //until False;
  until L > R;
  v := A[L];
  A[L] := A[R];
  A[R] := v;

  Result.Left := R;
  Result.Right := L;
end;

class procedure TGSimpleArrayHelper.DoQSort(var A: array of T; L, R: SizeInt);
begin
  while R - L > QUICK_INSERTION_SORT_CUTOFF do
    with QSplitR(A, L, R) do
      if Left - L <= R - Right then
        begin
          DoQSort(A, L, Left);
          L := Right;
        end
      else
        begin
          DoQSort(A, Right, R);
          R := Left;
        end;
  if R - L > 0 then
    if L = 0 then
      InsertionSort(A, L, R)
    else
      UnguardInsertionSort(A, L, R);
end;

class function TGSimpleArrayHelper.MedianOf3(p1, p2, p3: PItem): PItem;
begin
  Result := p2;
  if p1^ < Result^ then
    begin
      if p3^ < Result^ then
        begin
          if p1^ < p3^ then
            Result := p3
          else
            Result := p1;
        end;
    end
  else { p1^ >= Result^ }
    begin
      if p3^ > Result^ then
        begin
          if p1^ > p3^ then
            Result := p3
          else
            Result := p1;
        end;
    end;
end;

class function TGSimpleArrayHelper.GetMo9Pivot(const A: array of T; L, R: SizeInt): T;
begin
  if R - L > MEDIAN_OF9_CUTOFF then
    Result := MedianOf3(
        MedianOf3(@A[L], @A[L + (R - L) shr 3], @A[L + (R - L) shr 2]),
        MedianOf3(@A[L + (R - L) shr 1 - (R - L) shr 3], @A[L + (R - L) shr 1],
                  @A[L + (R - L) shr 1 + (R - L) shr 3]),
        MedianOf3(@A[R - (R - L) shr 2], @A[R - (R - L) shr 3], @A[R]))^
  else
    Result := MedianOf3(@A[L], @A[L + (R - L) shr 1], @A[R])^;
end;

class function TGSimpleArrayHelper.QSplitMo9(var A: array of T; L, R: SizeInt): TSortSplit;
var
  v, Pivot: T;
begin
  Pivot := GetMo9Pivot(A, L, R);
  Dec(L);
  Inc(R);
  repeat
    repeat
      Inc(L);
    until A[L] >= Pivot;
    repeat
      Dec(R);
    until A[R] <= Pivot;
    if L > R then
      break;
    v := A[L];
    A[L] := A[R];
    A[R] := v;
  until False;
  Result.Left := R;
  Result.Right := L;
end;

class procedure TGSimpleArrayHelper.DoIntroSort(var A: array of T; L, R, Ttl: SizeInt);
begin
  if R - L > QUICK_INSERTION_SORT_CUTOFF then
    if Ttl > 0 then
      with QSplitMo9(A, L, R) do
        begin
          if Left > L then
            DoIntroSort(A, L, Left, Pred(Ttl));
          if Right < R then
            DoIntroSort(A, Right, R, Pred(Ttl));
        end
    else
      DoHeapSort(@A[L], R - L)
  else
    if R - L > 0 then
      if L = 0 then
        InsertionSort(A, L, R)
      else
        UnguardInsertionSort(A, L, R);
end;

class function TGSimpleArrayHelper.DPQSplit(var A: array of T; L, R: SizeInt): TSortSplit;
var
  v, Pivot1, Pivot2: T;
  pL, pR, I: SizeInt;
label
  EndLoop;
begin
  pL := Succ(L + Random(Pred((R - L) shr 1)));
  //pR := Pred(R - Random(Pred((R - L) shr 1)));
  pR := pL + (R - L) shr 1;

  if A[pL] <= A[pR] then
    begin
      Pivot1 := A[pL];
      A[pL] := A[L];
      Pivot2 := A[pR];
      A[pR] := A[R];
    end
  else
    begin
      Pivot2 := A[pL];
      A[pL] := A[R];
      Pivot1 := A[pR];
      A[pR] := A[L];
    end;

  pL := Succ(L);
  I  := Succ(L);
  pR := Pred(R);
  while I <= pR do
    begin
      v := A[I];
      if v < Pivot1 then
        begin
          A[I] := A[pL];
          A[pL] := v;
          Inc(pL);
        end
      else
        if v > Pivot2 then
          begin
            while A[pR] > Pivot2 do
              begin
                Dec(pR);
                if pR < I then
                  goto EndLoop;
              end;
            if A[pR] < Pivot1 then
              begin
                A[I] := A[pL];
                A[pL] := A[pR];
                Inc(pL);
              end
            else
              A[I] := A[pR];
            A[pR] := v;
            Dec(pR);
          end;
      Inc(I);
    end;

EndLoop:

  A[L] := A[pL - 1];
  A[pL - 1] := Pivot1;
  A[R] := A[pR + 1];
  A[pR + 1] := Pivot2;

  Result.Left := pL - 1;
  Result.Right := pR + 1;
end;

class procedure TGSimpleArrayHelper.DoDPQSort(var A: array of T; L, R: SizeInt);
begin
  if R - L > DPQ_INSERTION_SORT_CUTOFF then
    with DPQSplit(A, L, R) do
      begin
        DoDPQSort(A, L, Left - 1);
        DoDPQSort(A, Right + 1, R);
        if A[Left] < A[Right] then
          DoDPQSort(A, Left + 1, Right - 1);
      end
  else
    if R - L > 0 then
      if L <> 0 then
        UnguardInsertionSort(A, L, R)
      else
        InsertionSort(A, L, R);
end;

class procedure TGSimpleArrayHelper.DoSwap(p: PItem; L, R: SizeInt);
var
  v: T;
begin
  v := p[L];
  p[L] := p[R];
  p[R] := v;
end;

class procedure TGSimpleArrayHelper.DoReverse(var A: array of T; L, R: SizeInt);
var
  v0, v1, v2, v3: T;
begin
  while R - L >= 7 do
    begin
      v0 := A[L    ];
      v1 := A[L + 1];
      v2 := A[L + 2];
      v3 := A[L + 3];
      A[L    ] := A[R    ];
      A[L + 1] := A[R - 1];
      A[L + 2] := A[R - 2];
      A[L + 3] := A[R - 3];
      A[R    ] := v0;
      A[R - 1] := v1;
      A[R - 2] := v2;
      A[R - 3] := v3;
      L += 4;
      R -= 4;
    end;
  case R - L of
    1..2:
      begin
        v0 := A[L];
        A[L] := A[R];
        A[R] := v0;
      end;
    3..4:
      begin
        v0 := A[L    ];
        v1 := A[L + 1];
        A[L    ] := A[R    ];
        A[L + 1] := A[R - 1];
        A[R    ] := v0;
        A[R - 1] := v1;
      end;
    5..6:
      begin
        v0 := A[L    ];
        v1 := A[L + 1];
        v2 := A[L + 2];
        A[L    ] := A[R    ];
        A[L + 1] := A[R - 1];
        A[L + 2] := A[R - 2];
        A[R    ] := v0;
        A[R - 1] := v1;
        A[R - 2] := v2;
      end;
  end;
end;

class function TGSimpleArrayHelper.QSelectR(var A: array of T; N: SizeInt): T;
var
  L, R, pL, pR: SizeInt;
  v, Pivot: T;
begin
  R := System.High(A);
  L := 0;
  while L < Pred(R) do
    begin
      Pivot := A[L + Random(Succ(R - L))];
      pL := Pred(L);
      pR := Succ(R);
      repeat
        repeat Inc(pL) until A[pL] >= Pivot;
        repeat Dec(pR) until A[pR] <= Pivot;
        if pL >= pR then break;
        v := A[pL];
        A[pL] := A[pR];
        A[pR] := v;
      until False;
      if pL = pR then
        begin
          if pL > L then
            Dec(pR)
          else
            if pL < R then
              Inc(pL);
        end;
      if pR < N then L := pL;
      if pL > N then R := pR;
    end;
  if (L < R) and (A[L] > A[R]) then
    begin
      v := A[L];
      A[L] := A[R];
      A[R] := v;
    end;
  Result := A[N];
end;

class procedure TGSimpleArrayHelper.Swap(var L, R: T);
var
  v: T;
begin
  v := L;
  L := R;
  R := v;
end;

class procedure TGSimpleArrayHelper.Reverse(var A: array of T);
begin
  if System.High(A) > 0 then
    DoReverse(A, 0, System.High(A));
end;

class procedure TGSimpleArrayHelper.RotateLeft(var A: array of T; aDist: SizeInt);
var
  Len: SizeInt;
begin
  if (aDist = 0) or (Abs(aDist) >= System.Length(A)) then
    exit;
  Len := System.Length(A);
  if aDist < 0 then
    aDist += Len;
  DoReverse(A, 0, Pred(aDist));
  DoReverse(A, aDist, Pred(Len));
  DoReverse(A, 0, Pred(Len));
end;

class procedure TGSimpleArrayHelper.RotateRight(var A: array of T; aDist: SizeInt);
begin
  if (aDist = 0) or (Abs(aDist) >= System.Length(A)) then
    exit;
  if aDist > 0 then
    RotateLeft(A, System.Length(A) - aDist)
  else
    RotateLeft(A, -aDist)
end;

class function TGSimpleArrayHelper.SequentSearch(const A: array of T; const aValue: T): SizeInt;
begin
  for Result := 0 to System.High(A) do
    if aValue = A[Result] then
      exit;
  Result := NULL_INDEX;
end;

class function TGSimpleArrayHelper.BinarySearch(const A: array of T; const aValue: T): SizeInt;
begin
  Result := System.High(A);
  if Result >= 0 then
    Result := DoBinSearch(@A[0], Result, aValue);
end;

class function TGSimpleArrayHelper.BinarySearchPos(const A: array of T; const aValue: T): TSearchResult;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R >= 0 then
    Result := DoBinSearchPos(@A[0], R, aValue)
  else
    Result := TSearchResult.Create(R, 0);
end;

class function TGSimpleArrayHelper.IndexOfMin(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if v > A[I] then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGSimpleArrayHelper.IndexOfMax(const A: array of T): SizeInt;
var
  R, I: SizeInt;
  v: T;
begin
  R := System.High(A);
  if R >= 0 then
    begin
      Result := 0;
      v := A[0];
      for I := 1 to R do
        if v < A[I] then
          begin
            v := A[I];
            Result := I;
          end;
    end
  else
    Result := R;
end;

class function TGSimpleArrayHelper.GetMin(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMin(A, v) then
    Result.Assign(v);
end;

class function TGSimpleArrayHelper.GetMax(const A: array of T): TOptional;
var
  v: T;
begin
  if FindMax(A, v) then
    Result.Assign(v);
end;

class function TGSimpleArrayHelper.FindMin(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aValue := A[0];
      for I := 1 to R do
        if aValue > A[I] then
          aValue := A[I];
    end;
end;

class function TGSimpleArrayHelper.FindMax(const A: array of T; out aValue: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aValue := A[0];
      for I := 1 to R do
        if aValue < A[I] then
          aValue := A[I];
    end;
end;

class function TGSimpleArrayHelper.FindMinMax(const A: array of T; out aMin, aMax: T): Boolean;
var
  R, I: SizeInt;
begin
  R := System.High(A);
  Result := R >= 0;
  if Result then
    begin
      aMin := A[0];
      aMax := A[0];
      for I := 1 to R do
        if A[I] > aMax then
          aMax := A[I]
        else
          if A[I] < aMin then
            aMin := A[I];
    end;
end;

class function TGSimpleArrayHelper.FindNthSmallest(var A: array of T; N: SizeInt; out aValue: T): Boolean;
var
  R: SizeInt;
begin
  R := System.High(A);
  if R < 0 then
    exit(False);
  if N <= 0 then
    exit(FindMin(A, aValue));
  if N >= R then
    exit(FindMax(A, aValue));
  aValue := QSelectR(A, N);
  Result := True;
end;

class function TGSimpleArrayHelper.NthSmallest(var A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallest(A, N, v) then
    Result.Assign(v);
end;

class function TGSimpleArrayHelper.FindNthSmallestND(const A: array of T; N: SizeInt; out aValue: T): Boolean;
begin
  Result := FindNthSmallest(CreateCopy(A), N, aValue);
end;

class function TGSimpleArrayHelper.NthSmallestND(const A: array of T; N: SizeInt): TOptional;
var
  v: T;
begin
  if FindNthSmallestND(A, N, v) then
    Result.Assign(v);
end;

class function TGSimpleArrayHelper.NextPermutation2Asc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if A[I] > A[Succ(I)] then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if A[J] > A[I] then
      begin
        DoSwap(@A[0], I, J);
        break;
      end;
  DoReverse(A, Succ(J), R);
  Result := True;
end;

class function TGSimpleArrayHelper.NextPermutation2Desc(var A: array of T): Boolean;
var
  I, J, R: SizeInt;
begin
  R := System.High(A);
  J := -1;
  for I := Pred(R) downto 0 do
    if A[I] < A[Succ(I)] then
      begin
        J := I;
        break;
      end;
  if J < 0 then exit(False);
  for I := R downto 0 do
    if A[J] < A[I] then
      begin
        DoSwap(@A[0], I, J);
        break;
      end;
  DoReverse(A, Succ(J), R);
  Result := True;
end;

class function TGSimpleArrayHelper.IsPermutation(const A, aPerm: array of T): Boolean;
var
  LocA, LocPerm: TArray;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  if Same(A, aPerm) then
    exit(True);
  LocA := CreateCopy(A);
  LocPerm := CreateCopy(aPerm);
  Sort(LocA);
  Sort(LocPerm);
  Result := Same(LocA, LocPerm);
end;

class function TGSimpleArrayHelper.IsNonDescending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if A[I] > A[Succ(I)] then
      exit(False);
  Result := True;
end;

class function TGSimpleArrayHelper.IsStrictAscending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if A[Pred(I)] >= A[I] then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGSimpleArrayHelper.IsNonAscending(const A: array of T): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.High(A)) do
    if A[I] < A[Succ(I)] then
      exit(False);
  Result := True;
end;

class function TGSimpleArrayHelper.IsStrictDescending(const A: array of T): Boolean;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      for I := 1 to R do
        if A[Pred(I)] <= A[I] then
          exit(False);
      Result := True;
    end
  else
    Result := False;
end;

class function TGSimpleArrayHelper.InversionCount(var A: array of T): Int64;
var
  Buf: TArray;
  function Merge(L, M, R: SizeInt): Int64;
  var
    I, J, K: SizeInt;
  begin
    I := L;
    J := Succ(M);
    Merge := 0;
    for K := 0 to R - L do
      if (J > R) or (I <= M) and (A[I] <= A[J]) then
        begin
          Buf[K] := A[I];
          Inc(I);
        end
      else
        begin
          Merge += Succ(M - I);
          Buf[K] := A[J];
          Inc(J);
        end;
    CopyItems(@Buf[0], @A[L], Succ(R - L));
  end;
  function InvCount(L, R: SizeInt): Int64;
  var
    M: SizeInt;
  begin
    if R <= L then
      exit(0);
    {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
    InvCount := InvCount(L, M);
    InvCount += InvCount(Succ(M), R);
    InvCount += Merge(L, M, R);
  end;
begin
  if System.Length(A) > 1 then
    begin
      System.SetLength(Buf, System.Length(A));
      exit(InvCount(0, System.High(A)));
    end;
  Result := 0;
end;

class function TGSimpleArrayHelper.InversionCountND(const A: array of T): Int64;
begin
  Result := InversionCount(CreateCopy(A));
end;

class function TGSimpleArrayHelper.IsSubSequence(const A, aSeq: array of T): Boolean;
var
  I, J: SizeInt;
begin
  I := 0;
  J := 0;
  while (I < System.Length(A)) and (J < System.Length(aSeq)) do
    begin
      if A[I] = aSeq[J] then
        Inc(J);
      Inc(I);
    end;
  Result := J = System.Length(aSeq);
end;

class function TGSimpleArrayHelper.LisI(const A: array of T): TSizeIntArray;
var
  TailIdx: array of SizeInt = nil;
  Parents: array of SizeInt = nil;
  function CeilIdx(const v: T; R: SizeInt): SizeInt;
  var
    L, M: SizeInt;
  begin
    L := 0;
    while L < R do
      begin
        {$PUSH}{$Q-}{$R-}M := (L + R) shr 1;{$POP}
        if v <= A[TailIdx[M]] then
          R := M
        else
          L := Succ(M);
      end;
    CeilIdx := R;
  end;
var
  r: array of SizeInt = nil;
  I, Idx, Len: SizeInt;
begin
  System.SetLength(TailIdx, System.Length(A));
  System.SetLength(Parents, System.Length(A));
  Len := 1;
  for I := 1 to System.High(A) do
    if A[I] < A[TailIdx[0]] then
      TailIdx[0] := I
    else
      if A[TailIdx[Pred(Len)]] < A[I] then
        begin
          Parents[I] := TailIdx[Pred(Len)];
          TailIdx[Len] := I;
          Inc(Len);
        end
      else
        begin
          Idx := CeilIdx(A[I], Pred(Len));
          Parents[I] := TailIdx[Pred(Idx)];
          TailIdx[Idx] := I;
        end;
  if Len < 2 then exit(nil);
  System.SetLength(r, Len);
  Idx := TailIdx[Pred(Len)];
  for I := Pred(Len) downto 0 do
    begin
      r[I] := Idx;
      Idx := Parents[Idx];
    end;
  Result := r;
end;

class function TGSimpleArrayHelper.Lis(const A: array of T): TArray;
var
  LocLis: TSizeIntArray;
  I: SizeInt;
begin
  LocLis := LisI(A);
  System.SetLength(Result, System.Length(LocLis));
  for I := 0 to System.High(LocLis) do
    Result[I] := A[LocLis[I]];
end;

class function TGSimpleArrayHelper.Same(const A, B: array of T): Boolean;
var
  I: SizeInt;
begin
  if System.Length(A) <> System.Length(B) then
    exit(False);
  if (System.Length(A) > 0) and (@A[0] <> @B[0]) then
    for I := 0 to System.High(A) do
      if A[I] <> B[I] then
        exit(False);
  Result := True;
end;

class procedure TGSimpleArrayHelper.QuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(A, 0, R, o) < R) then
    begin
      DoQSort(A, 0, R);
      if o = soDesc then
        DoReverse(A, 0, R);
    end;
end;

class procedure TGSimpleArrayHelper.IntroSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(A, 0, R, o) < R) then
    begin
      DoIntroSort(A, 0, R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR);
      if o = soDesc then
        DoReverse(A, 0, R);
    end;
end;

class procedure TGSimpleArrayHelper.DualPivotQuickSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(A, 0, R, o) < R) then
    begin
      DoDPQSort(A, 0, R);
      if o = soDesc then
        DoReverse(A, 0, R);
    end;
end;

class procedure TGSimpleArrayHelper.PDQSort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(A, 0, R, o) < R) then
    begin
      TBlockQSort.PDQSort(@A[0], @A[R] + 1);
      if o = soDesc then
        DoReverse(A, 0, R);
    end;
end;

class procedure TGSimpleArrayHelper.Sort(var A: array of T; o: TSortOrder);
begin
  PDQSort(A, o);
end;

class function TGSimpleArrayHelper.Sorted(const A: array of T; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, o);
end;

class function TGSimpleArrayHelper.SelectDistinct(const A: array of T): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if Result[I] = Result[J] then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGNumArrayHelper }

class constructor TGNumArrayHelper.Init;
begin
  case GetTypeKind(T) of
    tkInteger:
      if GetTypeData(TypeInfo(T))^.MinValue < 0 then
        CFKeyKind := itSInt
      else
        CFKeyKind := itUInt;
    tkInt64:
      if GetTypeData(TypeInfo(T))^.MinInt64Value < 0 then
        CFKeyKind := itSInt
      else
        CFKeyKind := itUInt;
    tkFloat:
      case GetTypeData(TypeInfo(T))^.FloatType of
        ftSingle, ftDouble, ftExtended: CFKeyKind := itFloat;
        ftCurr, ftComp: CFKeyKind := itSInt;
      end
  else
    CFKeyKind := itUInt;
  end;
end;

class procedure TGNumArrayHelper.FillOffsets(const A: array of T; out aOfs: TOffsets);
var
  Curr: T;
  I, J: SizeInt;
begin
  System.FillChar(aOfs, SizeOf(aOfs), 0);
  for I := 0 to System.High(A) do
    begin
      Curr := A[I];
      for J := 0 to Pred(SizeOf(T)) do
        Inc(aOfs[J, TKeyBytes(Curr)[J]]);
    end;
end;

class procedure TGNumArrayHelper.DoRxSortA(var A: array of T; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 1 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function IntSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 129 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    Ofs[0] += Ofs[255];
    for I := 1 to 127 do
      Ofs[I] += Ofs[Pred(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function FloatSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I, Save, Sum: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 254 downto 128 do
      Ofs[I] += Ofs[Succ(I)];
    Sum := Ofs[128];
    for I := 0 to 127 do
      begin
        Save := Ofs[I];
        Ofs[I] := Sum;
        Sum += Save;
      end;
    for I := 0 to System.High(A) do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        if b < 128 then
          begin
            aDst[Ofs[b]] := Curr;
            Inc(Ofs[b]);
          end
        else
          begin
            aDst[Pred(Ofs[b])] := Curr;
            Dec(Ofs[b]);
          end;
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := aBuf;
{$IFDEF ENDIAN_LITTLE}
  for I := 0 to SizeOf(T) - 2 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    itUInt:
      if SimplePass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    itSInt:
      if IntSignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    itFloat:
      if FloatSignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
  end;
{$ELSE ENDIAN_LITTLE}
  for I := Pred(SizeOf(T)) downto 1 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
  end;
{$ENDIF ENDIAN_LITTLE}
  if pBuf <> aBuf then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGNumArrayHelper.DoRxSortD(var A: array of T; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 254 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function IntSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 126 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    Ofs[255] += Ofs[0];
    for I := 254 downto 128 do
      Ofs[I] += Ofs[Succ(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function FloatSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: T;
    Ofs: PSizeInt;
    I, Save, Sum: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    Sum := 0;
    for I := 127 downto 0 do
      begin
        Save := Ofs[I];
        Ofs[I] := Sum;
        Sum += Save;
      end;
    Ofs[128] += Sum;
    for I := 129 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    for I := 0 to System.High(A) do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(Curr)[aIndex];
        if b < 128 then
          begin
            aDst[Ofs[b]] := Curr;
            Inc(Ofs[b]);
          end
        else
          begin
            aDst[Pred(Ofs[b])] := Curr;
            Dec(Ofs[b]);
          end;
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := aBuf;
{$IFDEF ENDIAN_LITTLE}
  for I := 0 to SizeOf(T) - 2 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    itUInt:
      if SimplePass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    itSInt:
      if IntSignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    itFloat:
      if FloatSignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
  end;
{$ELSE ENDIAN_LITTLE}
  for I := Pred(SizeOf(T)) downto 1 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
  end;
{$ENDIF ENDIAN_LITTLE}
  if pBuf <> aBuf then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGNumArrayHelper.DoRadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder);
var
  Offsets: TOffsets;
  StBuf: array[0..Pred(RADIX_BUF_SIZE)] of T;
  pBuf: PItem;
begin
  if System.Length(aBuf) < System.Length(A) then
    if System.Length(A) <= RADIX_BUF_SIZE then
      pBuf := @StBuf[0]
    else
      begin
        System.SetLength(aBuf, System.Length(A));
        pBuf := Pointer(aBuf);
      end
  else
    pBuf := Pointer(aBuf);

  FillOffsets(A, Offsets);

  if o = soAsc then
    DoRxSortA(A, pBuf, Offsets)
  else
    DoRxSortD(A, pBuf, Offsets);
end;

class procedure TGNumArrayHelper.RadixSort(var A: array of T; o: TSortOrder);
var
  Buf: TArray = nil;
begin
  RadixSort(A, Buf, o);
end;

class procedure TGNumArrayHelper.RadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    DoRadixSort(A, aBuf, o);
end;

class procedure TGNumArrayHelper.Sort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
  Buf: TArray = nil;
begin
  R := System.High(A);
  if (R > 0) and (CountRun(A, 0, R, o) < R) then
    begin
      if R <= RADIX_CUTOFF then
        begin
          DoIntroSort(A, 0, R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR);
          if o = soDesc then
            DoReverse(A, 0, R);
          exit;
        end;
      DoRadixSort(A, Buf, o);
    end;
end;

class function TGNumArrayHelper.Sorted(const A: array of T; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, o);
end;

class function TGNumArrayHelper.SelectDistinct(const A: array of T): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if Result[I] = Result[J] then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

{ TGOrdinalArrayHelper }

class procedure TGOrdinalArrayHelper.CountSort(var A: array of T; aMinValue, aMaxValue: T; o:  TSortOrder);
var
  I, J: SizeInt;
  v: T;
  Counts: array of SizeInt = nil;
begin
  System.SetLength(Counts, Succ(aMaxValue - aMinValue));
  //System.FillChar(Counts[0], Succ(aMaxValue - aMinValue) * SizeOf(SizeInt), 0);

  for J := 0 to System.High(A) do
    Inc(Counts[A[J] - aMinValue]);
  if o = soAsc then
    begin
      J := High(A);
      for I := aMaxValue - aMinValue downto 0 do
        if Counts[I] > 0 then
          begin
            v := T(I) + aMinValue;
            repeat
              A[J] := v;
              Dec(Counts[I]);
              Dec(J);
            until Counts[I] = 0;
          end;
    end
  else
    begin
      J := 0;
      for I := aMaxValue - aMinValue downto 0 do
        if Counts[I] > 0 then
          begin
            v := T(I) + aMinValue;
            repeat
              A[J] := v;
              Dec(Counts[I]);
              Inc(J);
            until Counts[I] = 0;
          end;
    end;
end;

class function TGOrdinalArrayHelper.TryInsertSortA2(var A: array of T; var aMin, aMax: T; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: T;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I] < A[I-1] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        if A[I] < aMin then
          aMin := A[I];
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = 0) or (v >= A[J-1]);
        A[J] := v;
        Dist += I - J;
      end
    else
      aMax := A[I];
   Result := R;
end;

class function TGOrdinalArrayHelper.TryInsertSortD2(var A: array of T; var aMin, aMax: T; L, R: SizeInt): SizeInt;
var
  I, J, Dist: SizeInt;
  v: T;
begin
  Dist := 0;
  for I := Succ(L) to R do
    if A[I-1] < A[I] then
      begin
        if Dist > TRY_INSERT_SORT_LIMIT then
          exit(Pred(I));
        if aMax < A[I] then
          aMax := A[I];
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = 0) or (v <= A[J-1]);
        A[J] := v;
        Dist += I - J;
      end
    else
      aMin := A[I];
   Result := R;
end;

class function TGOrdinalArrayHelper.Scan(var A: array of T; out aMinValue, aMaxValue: T): TMonoKind;
var
  I, R: SizeInt;
begin
  R := System.High(A);
  Result := mkConst;
  I := 0;
  aMinValue := A[0];
  aMaxValue := A[0];
  while (I < R) and (A[I] = A[Succ(I)]) do
    Inc(I);
  if I < R then
    begin
      Inc(I);
      if A[Pred(I)] < A[I] then  // ascending
        begin
          Result := mkAsc;
          I := TryInsertSortA2(A, aMinValue, aMaxValue, I, R);
        end
      else                       // descending
        begin
          Result := mkDesc;
          I := TryInsertSortD2(A, aMinValue, aMaxValue, I, R);
        end;
    end;
  if I < R then
    begin
      Result := mkNone;
      repeat
        if A[I] < aMinValue then
          aMinValue := A[I]
        else
          if A[I] > aMaxValue then
            aMaxValue := A[I];
        Inc(I);
      until I > R;
    end;
end;
{$PUSH}{$Q-}{$R-}
class function TGOrdinalArrayHelper.AllowCsSigned(aMin, aMax: T; aLen: SizeInt): Boolean;
var
  Sum: Int64;
begin
  if CFItemSize > 4 then
    aLen := aLen div 3 //todo: more tests needed
  else
    aLen := aLen div 6;
  Sum := Int64(aMin) + aLen;
  if Sum < Int64(aMin) then
    Result := (Int64(aMax) - Int64(aMin)) < aLen
  else
    Result := Int64(aMax) <= Sum;
end;

class function TGOrdinalArrayHelper.AllowCsUnsigned(aMin, aMax: T; aLen: SizeInt): Boolean;
var
  Sum: QWord;
begin
  if CFItemSize > 4 then
    aLen := aLen div 3 //todo: more tests needed
  else
    aLen := aLen div 6;
  Sum := QWord(aMin) + QWord(aLen);
  if Sum < QWord(aMin) then
    Result := QWord(aMax) - QWord(aMin) < aLen
  else
    Result := QWord(aMax) <= Sum;
end;
{$POP}
class procedure TGOrdinalArrayHelper.FillOffsets(const A: array of T; out aOfs: TOffsets);
var
  Curr: T;
  I, J: SizeInt;
begin
  System.FillChar(aOfs, SizeOf(aOfs), 0);
  for I := 0 to System.High(A) do
    begin
      Curr := A[I];
      for J := 0 to Pred(SizeOf(T)) do
        Inc(aOfs[J, (Curr shr (J * 8)) and $ff]);
    end;
end;

class procedure TGOrdinalArrayHelper.DoRxSortA(var A: array of T; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aNum: SizeInt): Boolean;
  var
    Curr: T;
    I: SizeInt;
    Ofs: PSizeInt;
  begin
    Ofs := @aOfs[aNum, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 1 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    aNum := aNum shl 3;
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        aDst[Pred(Ofs[(Curr shr aNum) and $ff])] := Curr;
        Dec(Ofs[(Curr shr aNum) and $ff]);
      end;
    Result := True;
  end;

  function SignedPass(aSrc, aDst: PItem; aNum: SizeInt): Boolean;
  var
    Curr: T;
    I: SizeInt;
    Ofs: PSizeInt;
  begin
    Ofs := @aOfs[aNum, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 129 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    Ofs[0] += Ofs[255];
    for I := 1 to 127 do
      Ofs[I] += Ofs[Pred(I)];
    aNum := aNum shl 3;
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        aDst[Pred(Ofs[(Curr shr aNum) and $ff])] := Curr;
        Dec(Ofs[(Curr shr aNum) and $ff]);
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := Pointer(aBuf);
  for I := 0 to SizeOf(T) - 2 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  if CFSigned then
    begin
      if SignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    end
  else
    if SimplePass(pA, pBuf, Pred(SizeOf(T))) then
      PtrSwap(pA, pBuf);
  if pBuf <> Pointer(aBuf) then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGOrdinalArrayHelper.DoRxSortD(var A: array of T; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aNum: SizeInt): Boolean;
  var
    Curr: T;
    I: SizeInt;
    Ofs: PSizeInt;
  begin
    Ofs := @aOfs[aNum, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 254 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    aNum := aNum shl 3;
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        aDst[Pred(Ofs[(Curr shr aNum) and $ff])] := Curr;
        Dec(Ofs[(Curr shr aNum) and $ff]);
      end;
    Result := True;
  end;

  function SignedPass(aSrc, aDst: PItem; aNum: SizeInt): Boolean;
  var
    Curr: T;
    I: SizeInt;
    Ofs: PSizeInt;
  begin
    Ofs := @aOfs[aNum, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 126 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    Ofs[255] += Ofs[0];
    for I := 254 downto 128 do
      Ofs[I] += Ofs[Succ(I)];
    aNum := aNum shl 3;
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        aDst[Pred(Ofs[(Curr shr aNum) and $ff])] := Curr;
        Dec(Ofs[(Curr shr aNum) and $ff]);
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := aBuf;
  for I := 0 to SizeOf(T) - 2 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  if CFSigned then
    begin
      if SignedPass(pA, pBuf, Pred(SizeOf(T))) then
        PtrSwap(pA, pBuf);
    end
  else
    if SimplePass(pA, pBuf, Pred(SizeOf(T))) then
      PtrSwap(pA, pBuf);
  if pBuf <> aBuf then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGOrdinalArrayHelper.DoRadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder);
var
  Offsets: TOffsets;
  StBuf: array[0..Pred(RADIX_BUF_SIZE)] of T;
  pBuf: PItem;
begin
  if System.Length(aBuf) < System.Length(A) then
    if System.Length(A) <= RADIX_BUF_SIZE then
      pBuf := @StBuf[0]
    else
      begin
        System.SetLength(aBuf, System.Length(A));
        pBuf := Pointer(aBuf);
      end
  else
    pBuf := Pointer(aBuf);

  FillOffsets(A, Offsets);

  if o = soAsc then
    DoRxSortA(A, pBuf, Offsets)
  else
    DoRxSortD(A, pBuf, Offsets);
end;

class constructor TGOrdinalArrayHelper.Init;
begin
  case GetTypeKind(T) of
    tkInteger: CFSigned := GetTypeData(TypeInfo(T))^.MinValue < 0;
    tkInt64:   CFSigned := GetTypeData(TypeInfo(T))^.MinInt64Value < 0;
  else
    CFSigned := False;
  end;
  if CFSigned then
    CountSortAllow := @AllowCsSigned
  else
    CountSortAllow := @AllowCsUnsigned;
  CFItemSize := SizeOf(T);
end;

class function TGOrdinalArrayHelper.CreateRange(aFirst, aLast: T): TArray;
var
  I: T;
  J: SizeInt = 0;
begin
  System.SetLength(Result, Succ(aLast - aFirst));
  for I := aFirst to aLast do
    begin
      Result[J] := I;
      Inc(J);
    end;
end;

class function TGOrdinalArrayHelper.CreateRandomRangePermutation(aRangeFirst, aRangeLast: T): TArray;
begin
  Result := CreateRange(aRangeFirst, aRangeLast);
  RandomShuffle(Result);
end;

class procedure TGOrdinalArrayHelper.RadixSort(var A: array of T; o: TSortOrder);
var
  Buf: TArray = nil;
begin
  RadixSort(A, Buf, o);
end;

class procedure TGOrdinalArrayHelper.RadixSort(var A: array of T; var aBuf: TArray; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if R > 0 then
    begin
      if R <= RADIX_CUTOFF then
        begin
          if CountRun(A, 0, R, o) < R then
            begin
              DoIntroSort(A, 0, R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR);
              if o = soDesc then
                DoReverse(A, 0, R);
            end;
          exit;
        end;
      if CountRun(A, 0, R, o) < R then
        DoRadixSort(A, aBuf, o);
    end;
end;

class procedure TGOrdinalArrayHelper.Sort(var A: array of T; o: TSortOrder);
var
  R: SizeInt;
  vMin, vMax: T;
  Mono: TMonoKind;
  Buf: TArray = nil;
begin
  R := System.High(A);
  if R > 0 then
    begin
      if R <= RADIX_CUTOFF then
        begin
          if CountRun(A, 0, R, o) < R then
            begin
              DoIntroSort(A, 0, R, LGUtils.NSB(R + 1) * INTROSORT_LOG_FACTOR);
              if o = soDesc then
                DoReverse(A, 0, R);
            end;
          exit;
        end;
      Mono := Scan(A, vMin, vMax);
      if Mono < mkNone then
        begin
          if (Mono <> mkConst) and (Ord(Mono) <> Ord(o)) then
            Reverse(A);
        end
      else
        if CountSortAllow(vMin, vMax, Succ(R)) then
          CountSort(A, vMin, vMax, o)
        else
          begin
            System.SetLength(Buf, System.Length(A));
            DoRadixSort(A, Buf, o);
          end;
    end;
end;

class function TGOrdinalArrayHelper.Sorted(const A: array of T; o: TSortOrder): TArray;
begin
  Result := CreateCopy(A);
  Sort(Result, o);
end;

class function TGOrdinalArrayHelper.SelectDistinct(const A: array of T): TArray;
var
  I, J: SizeInt;
begin
  Result := Sorted(A);
  if System.High(Result) < 1 then exit;
  I := 0;
  for J := 1 to System.High(Result) do
    begin
      if Result[I] = Result[J] then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

class constructor TGRadixSorter.Init;
begin
  case GetTypeKind(TKey) of
    tkInteger:
      if GetTypeData(TypeInfo(TKey))^.MinValue < 0 then
        CFKeyKind := ktSInt
      else
        CFKeyKind := ktUInt;
    tkInt64:
      if GetTypeData(TypeInfo(TKey))^.MinInt64Value < 0 then
        CFKeyKind := ktSInt
      else
        CFKeyKind := ktUInt;
    tkFloat:
      case GetTypeData(TypeInfo(TKey))^.FloatType of
        ftSingle, ftDouble, ftExtended: CFKeyKind := ktFloat;
        ftCurr, ftComp: CFKeyKind := ktSInt;
      end
  else
    CFKeyKind := ktUInt;
  end;
end;

class procedure TGRadixSorter.FillOffsets(const A: array of TItem; out aOfs: TOffsets);
var
  Key: TKey;
  I, J: SizeInt;
begin
  System.FillChar(aOfs, SizeOf(aOfs), 0);
  for I := 0 to System.High(A) do
    begin
      Key := TMap.GetKey(A[I]);
      for J := 0 to Pred(SizeOf(TKey)) do
        Inc(aOfs[J, TKeyBytes(Key)[J]]);
    end;
end;

class procedure TGRadixSorter.DoSortA(var A: array of TItem; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 1 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function IntSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 129 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    Ofs[0] += Ofs[255];
    for I := 1 to 127 do
      Ofs[I] += Ofs[Pred(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function FloatSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I, Save, Sum: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 254 downto 128 do
      Ofs[I] += Ofs[Succ(I)];
    Sum := Ofs[128];
    for I := 0 to 127 do
      begin
        Save := Ofs[I];
        Ofs[I] := Sum;
        Sum += Save;
      end;
    for I := 0 to System.High(A) do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        if b < 128 then
          begin
            aDst[Ofs[b]] := Curr;
            Inc(Ofs[b]);
          end
        else
          begin
            aDst[Pred(Ofs[b])] := Curr;
            Dec(Ofs[b]);
          end;
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := aBuf;
{$IFDEF ENDIAN_LITTLE}
  for I := 0 to SizeOf(TKey) - 2 do
    if SimplePass(pA, pBuf, I) then
      THelper.PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
  end;
{$ELSE ENDIAN_LITTLE}
  for I := Pred(SizeOf(TKey)) downto 1 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
  end;
{$ENDIF ENDIAN_LITTLE}
  if pBuf <> aBuf then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGRadixSorter.DoSortD(var A: array of TItem; aBuf: PItem; var aOfs: TOffsets);

  function SimplePass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 254 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function IntSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    for I := 126 downto 0 do
      Ofs[I] += Ofs[Succ(I)];
    Ofs[255] += Ofs[0];
    for I := 254 downto 128 do
      Ofs[I] += Ofs[Succ(I)];
    for I := System.High(A) downto 0 do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        aDst[Pred(Ofs[b])] := Curr;
        Dec(Ofs[b]);
      end;
    Result := True;
  end;

  function FloatSignedPass(aSrc, aDst: PItem; aIndex: SizeInt): Boolean;
  var
    Curr: TItem;
    Ofs: PSizeInt;
    I, Save, Sum: SizeInt;
    b: Byte;
  begin
    Ofs := @aOfs[aIndex, 0];
    for I := 0 to 255 do
      if Ofs[I] <> 0 then
        if Ofs[I] = System.Length(A) then
          exit(False)
        else
          break;
    Sum := 0;
    for I := 127 downto 0 do
      begin
        Save := Ofs[I];
        Ofs[I] := Sum;
        Sum += Save;
      end;
    Ofs[128] += Sum;
    for I := 129 to 255 do
      Ofs[I] += Ofs[Pred(I)];
    for I := 0 to System.High(A) do
      begin
        Curr := aSrc[I];
        b := TKeyBytes(TMap.GetKey(Curr))[aIndex];
        if b < 128 then
          begin
            aDst[Ofs[b]] := Curr;
            Inc(Ofs[b]);
          end
        else
          begin
            aDst[Pred(Ofs[b])] := Curr;
            Dec(Ofs[b]);
          end;
      end;
    Result := True;
  end;

var
  I: SizeInt;
  pA, pBuf: PItem;
begin
  pA := @A[0];
  pBuf := aBuf;
{$IFDEF ENDIAN_LITTLE}
  for I := 0 to SizeOf(TKey) - 2 do
    if SimplePass(pA, pBuf, I) then
      THelper.PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, Pred(SizeOf(TKey))) then
        THelper.PtrSwap(pA, pBuf);
  end;
{$ELSE ENDIAN_LITTLE}
  for I := Pred(SizeOf(TKey)) downto 1 do
    if SimplePass(pA, pBuf, I) then
      PtrSwap(pA, pBuf);
  case CFKeyKind of
    ktUInt:
      if SimplePass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktSInt:
      if IntSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
    ktFloat:
      if FloatSignedPass(pA, pBuf, 0) then
        PtrSwap(pA, pBuf);
  end;
{$ENDIF ENDIAN_LITTLE}
  if pBuf <> aBuf then
    for I := 0 to System.High(A) do
      A[I] := aBuf[I];
end;

class procedure TGRadixSorter.DoSort(var A: array of TItem; var aBuf: TArray; o: TSortOrder);
var
  Offsets: TOffsets;
  StBuf: array[0..Pred(RADIX_BUF_SIZE)] of TItem;
  pBuf: PItem;
begin
  if System.Length(aBuf) < System.Length(A) then
    if System.Length(A) <= RADIX_BUF_SIZE then
      pBuf := @StBuf[0]
    else
      begin
        System.SetLength(aBuf, System.Length(A));
        pBuf := Pointer(aBuf);
      end
  else
    pBuf := Pointer(aBuf);

  FillOffsets(A, Offsets);

  if o = soAsc then
    DoSortA(A, pBuf, Offsets)
  else
    DoSortD(A, pBuf, Offsets);
end;

class function TGRadixSorter.Less(const L, R: TItem): Boolean;
begin
  Result := TMap.GetKey(L) < TMap.GetKey(R);
end;

class procedure TGRadixSorter.Sort(var A: array of TItem; o: TSortOrder);
var
  Buf: TArray = nil;
begin
  Sort(A, Buf, o);
end;

class procedure TGRadixSorter.Sort(var A: array of TItem; var aBuf: TArray; o: TSortOrder);
var
  R: SizeInt;
begin
  R := System.High(A);
  if (R > 0) and (THelper.CountRun(@A[0], R, o) < R) then
    begin
      if R <= RADIX_CUTOFF then
        begin
          THelper.DoIntroSort(@A[0], R, LGUtils.NSB(R + 1) * THelper.INTROSORT_LOG_FACTOR, True);
          if o = soDesc then
            THelper.DoReverse(@A[0], R);
          exit;
        end;
      DoSort(A, aBuf, o);
    end;
end;

{ TGSegmentTree }

procedure TGSegmentTree.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(FElemCount) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGSegmentTree.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := FTree[aIndex + FLeafBound];
end;

procedure TGSegmentTree.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  aIndex += FLeafBound;
  FTree[aIndex] := aValue;
  repeat
    aIndex := Pred(Succ(aIndex) shr 1);
    FTree[aIndex] := TMonoid.BinOp(FTree[Succ(aIndex shl 1)], FTree[Succ(aIndex) shl 1]);
  until aIndex = 0;
end;

class function TGSegmentTree.GetIdentity: T;
begin
  Result := TMonoid.Identity;
end;

class operator TGSegmentTree.Initialize(var st: TGSegmentTree);
begin
  st.FElemCount := 0;
end;

constructor TGSegmentTree.Create(const a: array of T);
var
  I, aLen, Pow2Bound: SizeInt;
begin
  aLen := System.Length(a);
  if aLen = 0 then
    begin
      FTree := nil;
      FElemCount := 0;
      exit;
    end;
  if aLen <= MAX_POSITIVE_POW2 div 4 then
    begin
      FElemCount := aLen;
      Pow2Bound := RoundUpTwoPower(aLen);
      FLeafBound := Pred(Pow2Bound);
      System.SetLength(FTree, Pow2Bound * 2);
      THelper.Fill(FTree[(Pow2Bound + Pred(aLen))..Pred(Pow2Bound * 2)], TMonoid.Identity);
      Dec(Pow2Bound);
      for I := 0 to Pred(aLen) do
        FTree[Pow2Bound + I] := a[I];
      for I := Pred(Pow2Bound) downto 0 do
        FTree[I] := TMonoid.BinOp(FTree[Succ(I shl 1)], FTree[Succ(I) shl 1]);
    end
  else
    raise EArgumentException.CreateFmt(SEArrayTooBigFmt, [aLen]);
end;

constructor TGSegmentTree.Create(aSize: SizeInt; aOnGetElem: TOnGetElem);
var
  I, Pow2Bound: SizeInt;
begin
  if aSize < 1 then
    begin
      FTree := nil;
      FElemCount := 0;
      exit;
    end;
  if aSize <= MAX_POSITIVE_POW2 div 4 then
    begin
      FElemCount := aSize;
      Pow2Bound := RoundUpTwoPower(aSize);
      FLeafBound := Pred(Pow2Bound);
      System.SetLength(FTree, Pow2Bound * 2);
      THelper.Fill(FTree[(Pow2Bound + Pred(aSize))..Pred(Pow2Bound * 2)], TMonoid.Identity);
      Dec(Pow2Bound);
      if aOnGetElem <> nil then
        for I := 0 to Pred(aSize) do
          aOnGetElem(I, FTree[Pow2Bound + I])
      else
        THelper.Fill(FTree[Pow2Bound..(Pow2Bound+aSize)], TMonoid.Identity);
      for I := Pred(Pow2Bound) downto 0 do
        FTree[I] := TMonoid.BinOp(FTree[Succ(I shl 1)], FTree[Succ(I) shl 1]);
    end
  else
    raise EArgumentException.CreateFmt(SEArgumentTooBigFmt, ['TGSegmentTree.Create', aSize]);
end;

constructor TGSegmentTree.Create(aSize: SizeInt; aOnGetElem: TNestGetElem);
var
  I, Pow2Bound: SizeInt;
begin
  if aSize < 1 then
    begin
      FTree := nil;
      FElemCount := 0;
      exit;
    end;
  if aSize <= MAX_POSITIVE_POW2 div 4 then
    begin
      FElemCount := aSize;
      Pow2Bound := RoundUpTwoPower(aSize);
      FLeafBound := Pred(Pow2Bound);
      System.SetLength(FTree, Pow2Bound * 2);
      THelper.Fill(FTree[(Pow2Bound + Pred(aSize))..Pred(Pow2Bound * 2)], TMonoid.Identity);
      Dec(Pow2Bound);
      if aOnGetElem <> nil then
        for I := 0 to Pred(aSize) do
          aOnGetElem(I, FTree[Pow2Bound + I])
      else
        THelper.Fill(FTree[Pow2Bound..(Pow2Bound+aSize)], TMonoid.Identity);
      for I := Pred(Pow2Bound) downto 0 do
        FTree[I] := TMonoid.BinOp(FTree[Succ(I shl 1)], FTree[Succ(I) shl 1]);
    end
  else
    raise EArgumentException.CreateFmt(SEArgumentTooBigFmt, ['TGSegmentTree.Create', aSize]);
end;

function TGSegmentTree.RangeQuery(L, R: SizeInt): T;
var
  vL, vR: T;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  vL := TMonoid.Identity;
  vR := TMonoid.Identity;
  L += FLeafBound;
  R += FLeafBound;
  while L < R do
    begin
      if not Odd(L) then
        vL := TMonoid.BinOp(vL, FTree[L]);
      L := L shr 1;
      if Odd(R) then
        vR := TMonoid.BinOp(FTree[R], vR);
      R := Pred(R shr 1);
    end;
  if L = R then
    vL := TMonoid.BinOp(vL, FTree[L]);
  Result := TMonoid.BinOp(vL, vR);
end;

end.

