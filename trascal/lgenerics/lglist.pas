{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic sorted list implementation.                                     *
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
unit lgList;

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

  { TGBaseSortedList is always sorted ascending;
      functor TCmpRel(comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseSortedList<T, TCmpRel> = class(specialize TGAbstractCollection<T>)
  protected
  type
    THelper     = class(specialize TGBaseArrayHelper<T, TCmpRel>);

    TEnumerator = class(TContainerEnumerator)
    private
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(aList: TGBaseSortedList);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnumerable = class(TContainerEnumerable)
    protected
      FItems: TArray;
      FCurrIndex,
      FCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(aList: TGBaseSortedList);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(aList: TGBaseSortedList; aLastIndex: SizeInt); overload;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TTailEnumerable = class(TContainerEnumerable)
    protected
      FItems: TArray;
      FCurrIndex,
      FStart,
      FLast: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(aList: TGBaseSortedList; aStartIndex: SizeInt); overload;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(TTailEnumerable)
      constructor Create(aList: TGBaseSortedList; aStartIndex, aLastIndex: SizeInt); overload;
    end;

    TRecEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
      function  GetCurrent: T; inline;
      procedure Init(aList: TGBaseSortedList);
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

  protected
  type
    TExtractHelper = object
    private
      FCurrIndex: SizeInt;
      FExtracted: TArray;
    public
      procedure Add(constref aValue: T);
      procedure Init;
      function  Final: TArray;
    end;

  var
    FItems: TArray;
    FCount: SizeInt;
    FRejectDuplicates: Boolean;
    function  GetCount: SizeInt; override;
    function  GetCapacity: SizeInt; override;
    procedure SetRejectDuplicates(aValue: Boolean);
    procedure DoClear; override;
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    procedure CopyItems(aBuffer: PItem); override;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure DoSetItem(aIndex: SizeInt; const aValue: T); virtual;
    procedure RemoveDuplicates;
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    function  DoAdd(const aValue: T): Boolean; override;
    function  DoInsert(const aValue: T): SizeInt;
    function  DoRemove(const aValue: T): Boolean; override;
    function  DoExtract(const aValue: T): Boolean; override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
    function  DoExtractIf(aTest: TTest): TArray; override;
    function  DoExtractIf(aTest: TOnTest): TArray; override;
    function  DoExtractIf(aTest: TNestTest): TArray; override;
    function  SelectDistinctArray(const a: array of T): TArray;
    function  DoAddAll(const a: array of T): SizeInt; override; overload;
    function  DoAddAll(e: IEnumerable): SizeInt; override; overload;
    function  IndexInRange(aIndex: SizeInt): Boolean; inline;
    procedure CheckIndexRange(aIndex: SizeInt);
    function  GetReverse: IEnumerable;
    procedure Expand(aValue: SizeInt);
    procedure ItemAdding;
    function  ExtractItem(aIndex: SizeInt): T;
    function  DeleteItem(aIndex: SizeInt): T; virtual;
    function  DoDeleteRange(aIndex, aCount: SizeInt): SizeInt; virtual;
    function  GetRecEnumerator: TRecEnumerator; inline; //for internal use
    function  RightmostLT(const aValue: T): SizeInt;
    function  RightmostLE(const aValue: T): SizeInt;
    function  LeftmostGT(const aValue: T): SizeInt;
    function  LeftmostGE(const aValue: T): SizeInt;
    property  ElemCount: SizeInt read FCount;
  public
    constructor CreateEmpty;
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor Create(aRejectDuplicates: Boolean);
    constructor Create(const a: array of T; aRejectDuplicates: Boolean);
    constructor Create(e: IEnumerable; aRejectDuplicates: Boolean);
    destructor  Destroy; override;

    function  Reverse: IEnumerable; override;
    function  ToArray: TArray; override;
    function  FindMin(out aValue: T): Boolean;
    function  FindMax(out aValue: T): Boolean;
  { returns insert position or -1 if element is not inserted }
    function  Insert(const aValue: T): SizeInt;
    function  Contains(const aValue: T): Boolean; override;
    procedure Delete(aIndex: SizeInt);
    function  TryDelete(aIndex: SizeInt): Boolean;
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt;
  { returns the index of the leftmost occurrence of aValue, -1 if there is no such element }
    function  IndexOf(const aValue: T): SizeInt;
  { returns the count of occurrences of aValue, 0 if there is no such element }
    function  CountOf(const aValue: T): SizeInt;
  { returns the leftmost index of the nearest element that is greater then or equal to
    aValue(depending on aInclusive), or -1 if there is no such element }
    function  IndexOfCeil(const aValue: T; aInclusive: Boolean = True): SizeInt;
  { returns the rightmost index of the nearest element that is TLess then aValue
    (or equal to aValue, depending on aInclusive), or -1 if there is no such element }
    function  IndexOfFloor(const aValue: T; aInclusive: Boolean = False): SizeInt;
  { enumerates values that are strictly TLess than(if not aInclusive) aHighBound }
    function  Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable;
  { enumerates values that are greater than or equal to(if aInclusive) aLowBound }
    function  Tail(const aLowBound: T; aInclusive: Boolean = True): IEnumerable;
  { enumerates values that are greater than or equal to aLowBound and strictly TLess than aHighBound(by default)}
    function  Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
    function  HeadList(const aHighBound: T; aInclusive: Boolean = False): TGBaseSortedList;
    function  TailList(const aLowBound: T; aInclusive: Boolean = True): TGBaseSortedList;
    function  SubList(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGBaseSortedList;
    function  Clone: TGBaseSortedList; override;
    property  RejectDuplicates: Boolean read FRejectDuplicates write SetRejectDuplicates;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

  { TGSortedList assumes that type T implements TCmpRel}
  generic TGSortedList<T> = class(specialize TGBaseSortedList<T, T>);

  { TGSortedList2: minimalistic sorted list }
  generic TGSortedList2<T, TCmpRel> = class
  private
  type
    TArray = array of T;

  public
  type
    TEnumerator = record
    private
      FList: TArray;
      FCurrIndex,
      FLastIndex: SizeInt;
      function  GetCurrent: T; inline;
    public
      constructor Create(aList: TGSortedList2);
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: T read GetCurrent;
    end;

  private
  type
    THelper = specialize TGBaseArrayHelper<T, TCmpRel>;

  var
    FItems: TArray;
    FCount: SizeInt;
    FAllowDuplicates: Boolean;
    function  GetCapacity: SizeInt; inline;
    procedure Expand(aValue: SizeInt);
    procedure ItemAdding; inline;
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    procedure RemoveItem(aIndex: SizeInt);
    procedure CapacityExceedError(aValue: SizeInt);
  public
    constructor CreateEmpty;
    constructor CreateEmpty(aAllowDuplicates: Boolean);
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(aCapacity: SizeInt; aAllowDuplicates: Boolean);
    destructor  Destroy; override;
    function  GetEnumerator: TEnumerator; inline;
    procedure Clear;
    function  EnsureCapacity(aValue: SizeInt): Boolean; inline;
    procedure TrimToFit; inline;
    function  Add(const aValue: T): Boolean;
    function  Contains(const aValue: T): Boolean;
    function  Remove(const aValue: T): Boolean;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  { by default False }
    property  AllowDuplicates: Boolean read FAllowDuplicates;
  end;

  { TGSortedListTable: table on top of sorted list }
  generic TGSortedListTable<TKey, TEntry, TCmpRel> = class
  private
  type
    TEntryList = array of TEntry;

  public
  type
    PEntry = ^TEntry;

    TEntryCmpRel = class
      class function Less(const L, R: TEntry): Boolean; static; inline;
    end;

    TEnumerator = record
    private
      FList: TEntryList;
      FCurrIndex,
      FLastIndex: SizeInt;
      function  GetCurrent: PEntry; inline;
    public
      constructor Create(aTable: TGSortedListTable);
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: PEntry read GetCurrent;
    end;

  private
    FItems: TEntryList;
    FCount: SizeInt;
    FAllowDuplicates: Boolean;
    function  GetCapacity: SizeInt; inline;
    procedure Expand(aValue: SizeInt);
    procedure ItemAdding; inline;
    procedure InsertItem(aIndex: SizeInt; constref aValue: TEntry);
    procedure RemoveItem(aIndex: SizeInt);
    procedure CapacityExceedError(aValue: SizeInt);
  public
    constructor CreateEmpty;
    constructor CreateEmpty(aAllowDuplicates: Boolean);
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(aCapacity: SizeInt; aAllowDuplicates: Boolean);
    destructor  Destroy; override;
    function  GetEnumerator: TEnumerator; inline;
    procedure Clear; //inline;
    function  EnsureCapacity(aValue: SizeInt): Boolean; inline;
    procedure TrimToFit; inline;
    function  FindOrAdd(const aKey: TKey; out e: PEntry; out aPos: SizeInt): Boolean;
    function  Find(const aKey: TKey; out aPos: SizeInt): PEntry;
    function  Add(const aKey: TKey): PEntry;
    function  Remove(const aKey: TKey): Boolean;
    procedure RemoveAt(aIndex: SizeInt); inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  { by default False }
    property  AllowDuplicates: Boolean read FAllowDuplicates;
  end;

  { TGLiteSortedList is always sorted ascending;
      functor TCmpRel(comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGLiteSortedList<T, TCmpRel> = record
  private
  type
    TBuffer         = specialize TGLiteDynBuffer<T>;
    THelper         = specialize TGBaseArrayHelper<T, TCmpRel>;
    PLiteSortedList = ^TGLiteSortedList;

  public
  type
    TEnumerator        = TBuffer.TEnumerator;
    TReverseEnumerator = TBuffer.TReverseEnumerator;
    TReverse           = TBuffer.TReverse;
    PItem              = TBuffer.PItem;
    TArray             = TBuffer.TArray;

    THeadEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aList: TGLiteSortedList; aLastIndex: SizeInt);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    THead = record
    private
      FList: PLiteSortedList;
      FHighBound: SizeInt;
    public
      constructor Create(aList: PLiteSortedList; aHighBound: SizeInt);
      function GetEnumerator: THeadEnumerator;
    end;

    TTailEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FStart,
      FLast: SizeInt;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aList: TGLiteSortedList; aStartIndex: SizeInt);
      constructor Create(const aList: TGLiteSortedList; aStartIndex, aLastIndex: SizeInt);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TTail = record
    private
      FList: PLiteSortedList;
      FLowBound: SizeInt;
    public
      constructor Create(aList: PLiteSortedList; aLowBound: SizeInt);
      function GetEnumerator: TTailEnumerator;
    end;

    TRange = record
    private
      FList: PLiteSortedList;
      FLowBound,
      FHighBound: SizeInt;
    public
      constructor Create(aList: PLiteSortedList; aLowBound, aHighBound: SizeInt);
      function GetEnumerator: TTailEnumerator;
    end;

  private
    FBuffer: TBuffer;
    FRejectDuplicates: Boolean;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; aValue: T);
    procedure DoSetItem(aIndex: SizeInt; const aValue: T);
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    function  ExtractItem(aIndex: SizeInt): T;
    function  DeleteItem(aIndex: SizeInt): T; inline;
    procedure RemoveDuplicates;
    procedure SetRejectDuplicates(aValue: Boolean);
    function  RightmostLT(const aValue: T): SizeInt;
    function  RightmostLE(const aValue: T): SizeInt;
    function  LeftmostGT(const aValue: T): SizeInt;
    function  LeftmostGE(const aValue: T): SizeInt;
    function  SelectDistinctArray(const a: array of T): TArray;
    function  GetHeadEnumerator(aHighBound: SizeInt): THeadEnumerator;
    function  GetTailEnumerator(aLowBound: SizeInt): TTailEnumerator;
    function  GetRangeEnumerator(aLowBound, aHighBound: SizeInt): TTailEnumerator;
    class operator Initialize(var lst: TGLiteSortedList);
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    function  FindMin(out aValue: T): Boolean;
    function  FindMax(out aValue: T): Boolean;
    function  FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
    function  Add(const aValue: T): Boolean;
    function  AddAll(const a: array of T): SizeInt;
    function  Remove(const aValue: T): Boolean;
  { returns insert position or -1 if element is not inserted }
    function  Insert(const aValue: T): SizeInt;
    function  Contains(const aValue: T): Boolean; inline;
    function  NonContains(const aValue: T): Boolean; inline;
    procedure Delete(aIndex: SizeInt);
    function  TryDelete(aIndex: SizeInt): Boolean;
  { returns the index of the leftmost occurrence of aValue, -1 if there is no such element }
    function  IndexOf(const aValue: T): SizeInt;
  { returns the count of occurrences of aValue, 0 if there is no such element }
    function  CountOf(const aValue: T): SizeInt;
  { returns the leftmost index of the nearest element that is greater then or equal to
    aValue(depending on aInclusive), or -1 if there is no such element }
    function  IndexOfCeil(const aValue: T; aInclusive: Boolean = True): SizeInt; inline;
  { returns the rightmost index of the nearest element that is less then aValue
    (or equal to aValue, depending on aInclusive), or -1 if there is no such element }
    function  IndexOfFloor(const aValue: T; aInclusive: Boolean = False): SizeInt; inline;
  { enumerates values that are strictly less than(if not aInclusive) aHighBound }
    function  Head(const aHighBound: T; aInclusive: Boolean = False): THead; inline;
  { enumerates values that are greater than or equal to(if aInclusive) aLowBound }
    function  Tail(const aLowBound: T; aInclusive: Boolean = True): TTail;
  { enumerates values that are greater than or equal to aLowBound and strictly less than aHighBound(by default)}
    function  Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TRange;
    function  HeadList(const aHighBound: T; aInclusive: Boolean = False): TGLiteSortedList;
    function  TailList(const aLowBound: T; aInclusive: Boolean = True): TGLiteSortedList;
    function  SubList(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGLiteSortedList;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  RejectDuplicates: Boolean read FRejectDuplicates write SetRejectDuplicates;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

  { TGLiteComparableSortedList is always sorted ascending;
    it assumes that type T has implemented comparison operator < }
  generic TGLiteComparableSortedList<T> = record
  private
  type
    TBuffer     = specialize TGLiteDynBuffer<T>;
    THelper     = specialize TGComparableArrayHelper<T>;
    TSortedList = TGLiteComparableSortedList;
    PSortedList = ^TSortedList;

  public
  type
    TEnumerator        = TBuffer.TEnumerator;
    TReverseEnumerator = TBuffer.TReverseEnumerator;
    TReverse           = TBuffer.TReverse;
    PItem              = TBuffer.PItem;
    TArray             = TBuffer.TArray;

    THeadEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
      function  GetCurrent: T; inline;
    public
      constructor Create(constref aList: TSortedList; aLastIndex: SizeInt);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    THead = record
    private
      FList: PSortedList;
      FHighBound: SizeInt;
    public
      constructor Create(aList: PSortedList; aHighBound: SizeInt);
      function GetEnumerator: THeadEnumerator; inline;
    end;

    TTailEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FStart,
      FLast: SizeInt;
      function  GetCurrent: T; inline;
    public
      constructor Create(const aList: TSortedList; aStartIndex: SizeInt);
      constructor Create(const aList: TSortedList; aStartIndex, aLastIndex: SizeInt);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TTail = record
    private
      FList: PSortedList;
      FLowBound: SizeInt;
    public
      constructor Create(aList: PSortedList; aLowBound: SizeInt);
      function GetEnumerator: TTailEnumerator;
    end;

    TRange = record
    private
      FList: PSortedList;
      FLowBound,
      FHighBound: SizeInt;
    public
      constructor Create(aList: PSortedList; aLowBound, aHighBound: SizeInt);
      function GetEnumerator: TTailEnumerator;
    end;

  private
    FBuffer: TBuffer;
    FRejectDuplicates: Boolean;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; aValue: T);
    procedure DoSetItem(aIndex: SizeInt; const aValue: T);
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    function  ExtractItem(aIndex: SizeInt): T;
    function  DeleteItem(aIndex: SizeInt): T; inline;
    procedure RemoveDuplicates;
    procedure SetRejectDuplicates(aValue: Boolean);
    function  RightmostLT(const aValue: T): SizeInt;
    function  RightmostLE(const aValue: T): SizeInt;
    function  LeftmostGT(const aValue: T): SizeInt;
    function  LeftmostGE(const aValue: T): SizeInt;
    function  SelectDistinctArray(const a: array of T): TArray;
    function  GetHeadEnumerator(aHighBound: SizeInt): THeadEnumerator;
    function  GetTailEnumerator(aLowBound: SizeInt): TTailEnumerator;
    function  GetRangeEnumerator(aLowBound, aHighBound: SizeInt): TTailEnumerator;
    class operator Initialize(var lst: TGLiteComparableSortedList);
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    function  FindMin(out aValue: T): Boolean;
    function  FindMax(out aValue: T): Boolean;
    function  FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
    function  Add(const aValue: T): Boolean;
    function  AddAll(const a: array of T): SizeInt;
    function  Remove(const aValue: T): Boolean;
  { returns insert position or -1 if element is not inserted }
    function  Insert(const aValue: T): SizeInt;
    function  Contains(const aValue: T): Boolean; inline;
    function  NonContains(const aValue: T): Boolean; inline;
    procedure Delete(aIndex: SizeInt);
    function  TryDelete(aIndex: SizeInt): Boolean;
  { returns the index of the leftmost occurrence of aValue, -1 if there is no such element }
    function  IndexOf(const aValue: T): SizeInt;
  { returns the count of occurrences of aValue, 0 if there is no such element }
    function  CountOf(const aValue: T): SizeInt;
  { returns the leftmost index of the nearest element that is greater then or equal to
    aValue(depending on aInclusive), or -1 if there is no such element }
    function  IndexOfCeil(const aValue: T; aInclusive: Boolean = True): SizeInt; inline;
  { returns the rightmost index of the nearest element that is less then aValue
    (or equal to aValue, depending on aInclusive), or -1 if there is no such element }
    function  IndexOfFloor(const aValue: T; aInclusive: Boolean = False): SizeInt; inline;
  { enumerates values that are strictly less than(if not aInclusive) aHighBound }
    function  Head(const aHighBound: T; aInclusive: Boolean = False): THead; inline;
  { enumerates values that are greater than or equal to(if aInclusive) aLowBound }
    function  Tail(const aLowBound: T; aInclusive: Boolean = True): TTail;
  { enumerates values that are greater than or equal to aLowBound and strictly less than aHighBound(by default)}
    function  Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TRange; inline;
    function  HeadList(const aHighBound: T; aInclusive: Boolean = False): TGLiteComparableSortedList;
    function  TailList(const aLowBound: T; aInclusive: Boolean = True): TGLiteComparableSortedList;
    function  SubList(const aLowBound, aHighBound: T;
              aIncludeBounds: TRangeBounds = [rbLow]): TGLiteComparableSortedList;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  RejectDuplicates: Boolean read FRejectDuplicates write SetRejectDuplicates;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

  { TGLiteHashList: array based list with fast searching by key or
      node based hash table with alter access by index;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteHashList<T, TEqRel> = record
  private
  type
    TNode = record
      Hash,
      Next: SizeInt;
      Data: T;
    end;
    PNode = ^TNode;

    TNodeList     = array of TNode;
    TChainList    = array of SizeInt;
    PLiteHashList = ^TGLiteHashList;

  public
  type
    IEnumerable = specialize IGEnumerable<T>;
    TArray      = array of T;

    TEnumerator = record
    private
      FCurrNode,
      FLastNode: PNode;
      function  GetCurrent: T; inline;
    public
      constructor Create(aList: PLiteHashList);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrNode,
      FFirstNode: PNode;
      function  GetCurrent: T; inline;
    public
      constructor Create(aList: PLiteHashList);
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TReverse = record
    private
      FList: PLiteHashList;
    public
      constructor Create(aList: PLiteHashList);
      function  GetEnumerator: TReverseEnumerator;
    end;

  private
    FNodeList: TNodeList;
    FChainList: TChainList;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure InitialAlloc;
    procedure Rehash;
    procedure Resize(aNewCapacity: SizeInt);
    procedure Expand;
    function  Find(const aValue: T; aHash: SizeInt): SizeInt; inline;
    function  Find(const aValue: T): SizeInt; inline;
    function  GetCountOf(const aValue: T): SizeInt;
    function  DoAdd(const aValue: T; aHash: SizeInt): SizeInt; inline;
    function  DoAdd(const aValue: T): SizeInt; inline;
    procedure DoInsert(aIndex: SizeInt; const aValue: T);
    procedure DoDelete(aIndex: SizeInt);
    procedure RemoveFromChain(aIndex: SizeInt);
    function  DoRemove(const aValue: T): Boolean;
  { returns True if aValue found, False otherwise }
    function  FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
    class procedure CapacityExceedError(aValue: SizeInt); static;
    class operator Initialize(var hl: TGLiteHashList);
    class operator Copy(constref aSrc: TGLiteHashList; var aDst: TGLiteHashList);
    class operator AddRef(var hl: TGLiteHashList);
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  ToArray: TArray;
    function  Reverse: TReverse; inline;
    procedure Clear;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt);
    procedure TrimToFit;
    function  Contains(const aValue: T): Boolean;
    function  NonContains(const aValue: T): Boolean;
    function  IndexOf(const aValue: T): SizeInt;
    function  CountOf(const aValue: T): SizeInt; inline;
  { returns index of the element added }
    function  Add(const aValue: T): SizeInt; inline;
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
    function  AddUniq(const aValue: T): Boolean; inline;
    function  AddAllUniq(const a: array of T): SizeInt;
    function  AddAllUniq(e: IEnumerable): SizeInt;
    function  AddOrUpdate(const aValue: T; out aIndex: SizeInt): Boolean; inline;
    function  AddOrUpdate(const aValue: T): Boolean; inline;
    function  AddAllOrUpdate(const a: array of T): SizeInt;
    function  AddAllOrUpdate(e: IEnumerable): SizeInt;
    procedure Insert(aIndex: SizeInt; const aValue: T);
    procedure Delete(aIndex: SizeInt); inline;
    function  Remove(const aValue: T): Boolean; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

type

  { TGLiteHashList2: array based list with fast searching by key or
      node based hash table with alter access by index;
      TEntry must have field Key: TKey;
      functor TKeyEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: TKey): SizeInt;
        class function Equal([const[ref]] L, R: TKey): Boolean; }
  generic TGLiteHashList2<TKey, TEntry, TKeyEqRel> = record
  private
  type
    TNode = record
      Hash,
      Next: SizeInt;
      Data: TEntry;
    end;
    PNode = ^TNode;

    TNodeList     = array of TNode;
    TChainList    = array of SizeInt;
    PLiteHashList = ^TGLiteHashList2;

  public
  type
    IEntryEnumerable = specialize IGEnumerable<TEntry>;
    TEntryArray      = array of TEntry;
    PEntry           = ^TEntry;

  private
    FNodeList: TNodeList;
    FChainList: TChainList;
    FCount: SizeInt;
    class procedure CapacityExceedError(aValue: SizeInt); static; inline;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): TEntry; inline;
    function  GetKey(aIndex: SizeInt): TKey; inline;
    function  GetMutable(aIndex: SizeInt): PEntry; inline;
    procedure SetItem(aIndex: SizeInt; const e: TEntry);
    procedure InitialAlloc;
    procedure Rehash;
    procedure Resize(aNewCapacity: SizeInt);
    procedure Expand; inline;
    function  FindEntry(const aKey: TKey; aHash: SizeInt): PEntry;
    function  DoFind(const aKey: TKey; aHash: SizeInt): SizeInt;
    function  DoFind(const aKey: TKey): SizeInt; inline;
    function  DoFindUniq(const aKey: TKey): PEntry;
    function  TestHasUniq(aIndex: SizeInt): Boolean;
    function  GetCountOf(const aKey: TKey): SizeInt;
    function  DoAdd(const e: TEntry): SizeInt; inline;
    function  DoAddHash(aHash: SizeInt): SizeInt; inline;
    procedure DoInsert(aIndex: SizeInt; const e: TEntry);
    procedure DoDelete(aIndex: SizeInt; out e: TEntry);
    procedure RemoveFromChain(aIndex: SizeInt);
    function  DoRemove(const aKey: TKey; out e: TEntry): Boolean;
    function  DoFindOrAdd(const aKey: TKey; out p: PEntry; out aIndex: SizeInt): Boolean;
    class operator Initialize(var hl: TGLiteHashList2);
    class operator Copy(constref aSrc: TGLiteHashList2; var aDst: TGLiteHashList2);
    class operator AddRef(var hl: TGLiteHashList2);
  public
  type

    TEnumerator = record
    private
      FCurrNode,
      FLastNode: PNode;
      function  GetCurrent: TEntry; inline;
      procedure Init(aList: PLiteHashList);
    public
      function  MoveNext: Boolean; inline;
      property  Current: TEntry read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FCurrNode,
      FFirstNode: PNode;
      function  GetCurrent: TEntry; inline;
      procedure Init(aList: PLiteHashList);
    public
      function  MoveNext: Boolean; inline;
      property  Current: TEntry read GetCurrent;
    end;

    TReverse = record
    private
      FList: PLiteHashList;
      procedure Init(aList: PLiteHashList); inline;
    public
      function  GetEnumerator: TReverseEnumerator; inline;
    end;

    TEqualEnumerator = record
    private
      FList: PLiteHashList;
      FKey: TKey;
      FCurrIdx,
      FHash: SizeInt;
      FInLoop: Boolean;
      function  GetCurrent: TEntry; inline;
      procedure Init(const aKey: TKey; aList: PLiteHashList);
    public
      function  MoveNext: Boolean;
      procedure Reset;
      property  Current: TEntry read GetCurrent;
    end;

    TEqualKeys = record
    private
      FKey: TKey;
      FList: PLiteHashList;
      procedure Init(const aKey: TKey; aList: PLiteHashList); inline;
    public
      function  GetEnumerator: TEqualEnumerator; inline;
    end;

    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  GetEqualEnumerator(const aKey: TKey): TEqualEnumerator; inline;
    function  ToArray: TEntryArray;
    function  Reverse: TReverse; inline;
    function  EqualKeys(const aKey: TKey): TEqualKeys;
    procedure Clear;
    procedure MakeEmpty;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit;
    function  Contains(const aKey: TKey): Boolean; inline;
    function  ContainsUniq(const aKey: TKey): Boolean; inline;
    function  NonContains(const aKey: TKey): Boolean; inline;
    function  Find(const aKey: TKey): PEntry; inline;
    function  FindOrAdd(const aKey: TKey; out p: PEntry): Boolean; inline;
    function  FindUniq(const aKey: TKey): PEntry; inline;
    function  IndexOf(const aKey: TKey): SizeInt;
    function  CountOf(const aKey: TKey): SizeInt; inline;
    function  Add(const e: TEntry): SizeInt; inline;
    function  AddAll(const a: array of TEntry): SizeInt;
    function  AddAll(e: IEntryEnumerable): SizeInt;
    function  AddUniq(const e: TEntry): Boolean; inline;
    function  AddUniq(const e: TEntry; out p: PEntry): Boolean; inline;
    function  AddAllUniq(const a: array of TEntry): SizeInt;
    function  AddAllUniq(e: IEntryEnumerable): SizeInt;
    function  AddOrUpdate(const e: TEntry; out aIndex: SizeInt): Boolean; inline;
    function  AddOrUpdate(const e: TEntry): Boolean; inline;
    function  AddAllOrUpdate(const a: array of TEntry): SizeInt;
    function  AddAllOrUpdate(e: IEntryEnumerable): SizeInt;
    function  HasUniqKey(aIndex: SizeInt): Boolean; inline;
    procedure Insert(aIndex: SizeInt; const e: TEntry);
    function  TryInsert(aIndex: SizeInt; const e: TEntry): Boolean;
    procedure Delete(aIndex: SizeInt; out e: TEntry); inline;
    function  TryDelete(aIndex: SizeInt; out e: TEntry): Boolean; inline;
    function  Remove(const aKey: TKey; out e: TEntry): Boolean; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Keys[aIndex: SizeInt]: TKey read GetKey;
    property  Items[aIndex: SizeInt]: TEntry read GetItem write SetItem; default;
  { does not checks index range }
    property  Mutable[aIndex: SizeInt]: PEntry read GetMutable;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGBaseSortedList.TEnumerator }

function TGBaseSortedList.TEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGBaseSortedList.TEnumerator.Create(aList: TGBaseSortedList);
begin
  inherited Create(aList);
  FItems := aList.FItems;
  FLast := Pred(aList.ElemCount);
  FCurrIndex := NULL_INDEX;
end;

function TGBaseSortedList.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

procedure TGBaseSortedList.TEnumerator.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGBaseSortedList.TReverseEnumerable }

function TGBaseSortedList.TReverseEnumerable.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGBaseSortedList.TReverseEnumerable.Create(aList: TGBaseSortedList);
begin
  inherited Create(aList);
  FItems := aList.FItems;
  FCount := aList.ElemCount;
  FCurrIndex := FCount;
end;

function TGBaseSortedList.TReverseEnumerable.MoveNext: Boolean;
begin
  Result := FCurrIndex > 0;
  FCurrIndex -= Ord(Result);
end;

procedure TGBaseSortedList.TReverseEnumerable.Reset;
begin
  FCurrIndex := FCount;
end;

{ TGBaseSortedList.THeadEnumerable }

function TGBaseSortedList.THeadEnumerable.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGBaseSortedList.THeadEnumerable.Create(aList: TGBaseSortedList; aLastIndex: SizeInt);
begin
  inherited Create(aList);
  FItems := aList.FItems;
  FLast := aLastIndex;
  FCurrIndex := NULL_INDEX;
end;

function TGBaseSortedList.THeadEnumerable.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

procedure TGBaseSortedList.THeadEnumerable.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGBaseSortedList.TTailEnumerable }

function TGBaseSortedList.TTailEnumerable.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGBaseSortedList.TTailEnumerable.Create(aList: TGBaseSortedList; aStartIndex: SizeInt);
begin
  inherited Create(aList);
  FItems := aList.FItems;
  FLast := Pred(aList.ElemCount);
  FStart := Pred(aStartIndex);
  FCurrIndex := FStart;
end;

function TGBaseSortedList.TTailEnumerable.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

procedure TGBaseSortedList.TTailEnumerable.Reset;
begin
  FCurrIndex := FStart;
end;

{ TGBaseSortedList.TRangeEnumerable }

constructor TGBaseSortedList.TRangeEnumerable.Create(aList: TGBaseSortedList; aStartIndex, aLastIndex: SizeInt);
begin
  inherited Create(aList, aStartIndex);
  FLast := aLastIndex;
end;

{ TGBaseSortedList.TRecEnumerator }

function TGBaseSortedList.TRecEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

procedure TGBaseSortedList.TRecEnumerator.Init(aList: TGBaseSortedList);
begin
  FItems := aList.FItems;
  FLast := Pred(aList.ElemCount);
  FCurrIndex := NULL_INDEX;
end;

function TGBaseSortedList.TRecEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

procedure TGBaseSortedList.TRecEnumerator.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGBaseSortedList.TExtractHelper }

procedure TGBaseSortedList.TExtractHelper.Add(constref aValue: T);
var
  c: SizeInt;
begin
  c := System.Length(FExtracted);
  if FCurrIndex = c then
    System.SetLength(FExtracted, c shl 1);
  FExtracted[FCurrIndex] := aValue;
  Inc(FCurrIndex);
end;

procedure TGBaseSortedList.TExtractHelper.Init;
begin
  FCurrIndex := 0;
  System.SetLength(FExtracted, ARRAY_INITIAL_SIZE);
end;

function TGBaseSortedList.TExtractHelper.Final: TArray;
begin
  System.SetLength(FExtracted, FCurrIndex);
  Result := FExtracted;
end;

{ TGBaseSortedList }

function TGBaseSortedList.GetCount: SizeInt;
begin
  Result := ElemCount;
end;

function TGBaseSortedList.GetCapacity: SizeInt;
begin
  Result := System.Length(FItems);
end;

procedure TGBaseSortedList.SetRejectDuplicates(aValue: Boolean);
begin
  if RejectDuplicates <> aValue then
    begin
      FRejectDuplicates := aValue;
      if RejectDuplicates then
        RemoveDuplicates;
    end;
end;

procedure TGBaseSortedList.DoClear;
begin
  FItems := nil;
  FCount := 0;
end;

function TGBaseSortedList.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGBaseSortedList.DoTrimToFit;
begin
  if System.Length(FItems) > ElemCount then
    System.SetLength(FItems, ElemCount);
end;

procedure TGBaseSortedList.DoEnsureCapacity(aValue: SizeInt);
begin
  if aValue > System.Length(FItems) then
    Expand(aValue);
end;

procedure TGBaseSortedList.CopyItems(aBuffer: PItem);
begin
  if ElemCount > 0 then
    THelper.CopyItems(@FItems[0], aBuffer, ElemCount);
end;

function TGBaseSortedList.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := FItems[aIndex];
end;

procedure TGBaseSortedList.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  DoSetItem(aIndex, aValue);
end;

procedure TGBaseSortedList.DoSetItem(aIndex: SizeInt; const aValue: T);
var
  sr: TSearchResult;
begin
  if TCmpRel.Less(aValue, FItems[aIndex]) or TCmpRel.Less(FItems[aIndex], aValue) then
    begin
      CheckInIteration;
      if ElemCount > 1 then
        begin
          sr := THelper.BinarySearchPos(FItems[0..Pred(ElemCount)], aValue);
          if (sr.FoundIndex > NULL_INDEX) and RejectDuplicates then
            exit;
          FItems[aIndex] := Default(T);  ///////////////
          if sr.InsertIndex > aIndex then
            System.Move(FItems[Succ(aIndex)], FItems[aIndex], sr.InsertIndex - aIndex)
          else
            System.Move(FItems[sr.InsertIndex], FItems[Succ(sr.InsertIndex)], aIndex - sr.InsertIndex);
          if IsManagedType(T) then
            System.FillChar(FItems[sr.InsertIndex], SizeOf(T), 0);
          FItems[sr.InsertIndex] := aValue;
        end;
    end
  else
    FItems[aIndex] := aValue; ///////
end;

procedure TGBaseSortedList.RemoveDuplicates;
var
  I, J, Hi: SizeInt;
begin
  Hi := Pred(ElemCount);
  if Hi < 1 then
    exit;
  I := 0;
  for J := 1 to Hi do
    begin
      if not(TCmpRel.Less(FItems[I], FItems[J]) or TCmpRel.Less(FItems[J], FItems[I])) then
        continue;
      Inc(I);
      if J > I then
        FItems[I] := FItems[J];
    end;
  FCount := Succ(I);
  if IsManagedType(T) then
    for I := ElemCount to Hi do
      FItems[I] := Default(T);
end;

procedure TGBaseSortedList.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  ItemAdding;
  if aIndex < ElemCount then
    begin
      System.Move(FItems[aIndex], FItems[Succ(aIndex)], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[aIndex], SizeOf(T), 0);
    end;
  FItems[aIndex] := aValue;
  Inc(FCount);
end;

function TGBaseSortedList.DoAdd(const aValue: T): Boolean;
var
  sr: TSearchResult;
begin
  if ElemCount > 0 then
    begin
      sr := THelper.BinarySearchPos(FItems[0..Pred(ElemCount)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(False);
      InsertItem(sr.InsertIndex, aValue);
    end
  else
    InsertItem(ElemCount, aValue);
  Result := True;
end;

function TGBaseSortedList.DoInsert(const aValue: T): SizeInt;
var
  sr: TSearchResult;
begin
  if ElemCount > 0 then
    begin
      sr := THelper.BinarySearchPos(FItems[0..Pred(ElemCount)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(NULL_INDEX);
      Result := sr.InsertIndex;
    end
  else
    Result := 0;
  InsertItem(Result, aValue);
end;

function TGBaseSortedList.DoRemove(const aValue: T): Boolean;
var
  Removed: SizeInt;
begin
  Removed := IndexOf(aValue);
  Result := Removed >= 0;
  if Result then
    DeleteItem(Removed);
end;

function TGBaseSortedList.DoExtract(const aValue: T): Boolean;
var
  Extracted: SizeInt;
begin
  Extracted := IndexOf(aValue);
  Result := Extracted >= 0;
  if Result then
    ExtractItem(Extracted);
end;

function TGBaseSortedList.DoRemoveIf(aTest: TTest): SizeInt;
var
  I, J: SizeInt;
begin
  Result := ElemCount;
  if Result > 0 then
    begin
      J := 0;
      for I := 0 to Pred(Result) do
        begin
          if aTest(FItems[I]) then
            continue;
          if I > J then
            FItems[J] := FItems[I];
          Inc(J);
        end;
      FCount := J;
      if IsManagedType(T) then
        for I := ElemCount to Pred(Result) do
          FItems[I] := Default(T);
      Result -= ElemCount;
    end;
end;

function TGBaseSortedList.DoRemoveIf(aTest: TOnTest): SizeInt;
var
  I, J: SizeInt;
begin
  Result := ElemCount;
  if Result > 0 then
    begin
      J := 0;
      for I := 0 to Pred(Result) do
        begin
          if aTest(FItems[I]) then
            continue;
          if I > J then
            FItems[J] := FItems[I];
          Inc(J);
        end;
      FCount := J;
      if IsManagedType(T) then
        for I := ElemCount to Pred(Result) do
          FItems[I] := Default(T);
      Result -= ElemCount;
    end;
end;

function TGBaseSortedList.DoRemoveIf(aTest: TNestTest): SizeInt;
var
  I, J: SizeInt;
begin
  Result := ElemCount;
  if Result > 0 then
    begin
      J := 0;
      for I := 0 to Pred(Result) do
        begin
          if aTest(FItems[I]) then
            continue;
          if I > J then
            FItems[J] := FItems[I];
          Inc(J);
        end;
      FCount := J;
      if IsManagedType(T) then
        for I := ElemCount to Pred(Result) do
          FItems[I] := Default(T);
      Result -= ElemCount;
    end;
end;

function TGBaseSortedList.DoExtractIf(aTest: TTest): TArray;
var
  h: TExtractHelper;
  I, J, OldCount: SizeInt;
begin
  if ElemCount = 0 then
    exit(nil);
  OldCount := ElemCount;
  h.Init;
  J := 0;
  for I := 0 to Pred(OldCount) do
    begin
      if aTest(FItems[I]) then
        begin
          h.Add(FItems[I]);
          continue;
        end;
      if I > J then
        FItems[J] := FItems[I];
      Inc(J);
    end;
  FCount := J;
  if IsManagedType(T) then
    for I := ElemCount to Pred(OldCount) do
      FItems[I] := Default(T);
  Result := h.Final;
end;

function TGBaseSortedList.DoExtractIf(aTest: TOnTest): TArray;
var
  h: TExtractHelper;
  I, J, OldCount: SizeInt;
begin
  if ElemCount = 0 then
    exit(nil);
  OldCount := ElemCount;
  h.Init;
  J := 0;
  for I := 0 to Pred(OldCount) do
    begin
      if aTest(FItems[I]) then
        begin
          h.Add(FItems[I]);
          continue;
        end;
      if I > J then
        FItems[J] := FItems[I];
      Inc(J);
    end;
  FCount := J;
  if IsManagedType(T) then
    for I := ElemCount to Pred(OldCount) do
      FItems[I] := Default(T);
  Result := h.Final;
end;

function TGBaseSortedList.DoExtractIf(aTest: TNestTest): TArray;
var
  h: TExtractHelper;
  I, J, OldCount: SizeInt;
begin
  if ElemCount = 0 then
    exit(nil);
  OldCount := ElemCount;
  h.Init;
  J := 0;
  for I := 0 to Pred(OldCount) do
    begin
      if aTest(FItems[I]) then
        begin
          h.Add(FItems[I]);
          continue;
        end;
      if I > J then
        FItems[J] := FItems[I];
      Inc(J);
    end;
  FCount := J;
  if IsManagedType(T) then
    for I := ElemCount to Pred(OldCount) do
      FItems[I] := Default(T);
  Result := h.Final;
end;

function TGBaseSortedList.SelectDistinctArray(const a: array of T): TArray;
var
  I, J, Hi: SizeInt;
begin
  Result := THelper.SelectDistinct(a);
  if ElemCount = 0 then
    exit;
  Hi := System.High(Result);
  I := NULL_INDEX;
  for J := 0 to Hi do
    begin
      if IndexOf(Result[J]) >= 0 then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

function TGBaseSortedList.DoAddAll(const a: array of T): SizeInt;
var
  OldCount: SizeInt;
  PSrc: PItem;
  da: TArray;
begin
  OldCount := ElemCount;
  if RejectDuplicates then
    begin
      da := SelectDistinctArray(a);
      Result := System.Length(da);
      if Result = 0 then
        exit;
      PSrc := @da[0];
    end
  else
    begin
      Result := System.Length(a);
      if Result = 0 then
        exit;
      PSrc := @a[0];
    end;
  DoEnsureCapacity(OldCount + Result);
  THelper.CopyItems(PSrc, @FItems[OldCount], Result);
  FCount += Result;
  if RejectDuplicates or (OldCount >= Result) then
    THelper.MergeSort(FItems[0..Pred(ElemCount)])
  else
    THelper.Sort(FItems[0..Pred(ElemCount)])
end;

function TGBaseSortedList.DoAddAll(e: IEnumerable): SizeInt;
begin
  if (e._GetRef = Self) and RejectDuplicates then
    exit(0);
  Result := DoAddAll(e.ToArray);
end;

function TGBaseSortedList.IndexInRange(aIndex: SizeInt): Boolean;
begin
  Result := (aIndex >= 0) and (aIndex < ElemCount);
end;

procedure TGBaseSortedList.CheckIndexRange(aIndex: SizeInt);
begin
  if not IndexInRange(aIndex) then
   IndexOutOfBoundError(aIndex);
end;

function TGBaseSortedList.GetReverse: IEnumerable;
begin
  Result := TReverseEnumerable.Create(Self);
end;

procedure TGBaseSortedList.Expand(aValue: SizeInt);
begin
  //there aValue > Capacity
  if aValue <= DEFAULT_CONTAINER_CAPACITY then
    System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY)
  else
    if aValue <= MAX_CONTAINER_SIZE div SizeOf(T) then
      begin
        aValue := Math.Min(MAX_CONTAINER_SIZE div SizeOf(T), LGUtils.RoundUpTwoPower(aValue));
        System.SetLength(FItems, aValue);
      end
    else
      CapacityExceedError(aValue);
end;

procedure TGBaseSortedList.ItemAdding;
begin
  if ElemCount = System.Length(FItems) then
    Expand(Succ(ElemCount));
end;

function TGBaseSortedList.ExtractItem(aIndex: SizeInt): T;
begin
  Result := FItems[aIndex];
  if IsManagedType(T) then
    FItems[aIndex] := Default(T);
  Dec(FCount);
  System.Move(FItems[Succ(aIndex)], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
  if IsManagedType(T) then
    System.FillChar(FItems[ElemCount], SizeOf(T), 0);
end;

function TGBaseSortedList.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

function TGBaseSortedList.DoDeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, ElemCount - aIndex);
  if Result > 0 then
    begin
      for I := aIndex to Pred(aIndex + Result) do
        FItems[I] := Default(T);
      FCount -= Result;
      if ElemCount - aIndex > 0 then
        System.Move(FItems[aIndex + Result], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[ElemCount], SizeOf(T) * Result, 0);
    end;
end;

function TGBaseSortedList.GetRecEnumerator: TRecEnumerator;
begin
  Result.Init(Self);
end;

function TGBaseSortedList.RightmostLT(const aValue: T): SizeInt;
begin
  if (ElemCount = 0) or not TCmpRel.Less(FItems[0], aValue) then
    exit(NULL_INDEX);
  if TCmpRel.Less(FItems[Pred(ElemCount)], aValue) then
    exit(Pred(ElemCount));
  Result := THelper.BiSearchLeftA(@FItems[0], Pred(ElemCount), aValue);
  if not(TCmpRel.Less(FItems[Result], aValue) or TCmpRel.Less(aValue, FItems[Result])) then
    Dec(Result);
end;

function TGBaseSortedList.RightmostLE(const aValue: T): SizeInt;
begin
  if (ElemCount = 0) or TCmpRel.Less(aValue, FItems[0]) then
    exit(NULL_INDEX);
  if not TCmpRel.Less(aValue, FItems[Pred(ElemCount)]) then
    exit(Pred(ElemCount));
  Result := THelper.BiSearchRightA(@FItems[0], Pred(ElemCount), aValue);
  if TCmpRel.Less(aValue, FItems[Result]) then
    Dec(Result);
end;

function TGBaseSortedList.LeftmostGT(const aValue: T): SizeInt;
begin
  if (ElemCount = 0) or not TCmpRel.Less(aValue, FItems[Pred(ElemCount)]) then
    exit(NULL_INDEX);
  if TCmpRel.Less(aValue, FItems[0]) then
    exit(0);
  Result := THelper.BinarySearchPos(FItems[0..Pred(ElemCount)], aValue).InsertIndex;
end;

function TGBaseSortedList.LeftmostGE(const aValue: T): SizeInt;
begin
  if (ElemCount = 0) or TCmpRel.Less(FItems[Pred(ElemCount)], aValue) then
    exit(NULL_INDEX);
  if not TCmpRel.Less(FItems[0], aValue) then
    exit(0);
  Result := THelper.BiSearchLeftA(@FItems[0], Pred(ElemCount), aValue);
end;

constructor TGBaseSortedList.CreateEmpty;
begin
  inherited Create;
end;

constructor TGBaseSortedList.Create;
begin
  System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY);
end;

constructor TGBaseSortedList.Create(aCapacity: SizeInt);
begin
  if aCapacity <= MAX_CONTAINER_SIZE div SizeOf(T) then
    begin
      if aCapacity < 0 then
        aCapacity := 0;
      System.SetLength(FItems, aCapacity);
    end
  else
    CapacityExceedError(aCapacity);
end;

constructor TGBaseSortedList.Create(const a: array of T);
begin
  FItems := THelper.CreateCopy(a);
  FCount := System.Length(FItems);
  if ElemCount > 0 then
    THelper.Sort(FItems);
end;

constructor TGBaseSortedList.Create(e: IEnumerable);
begin
  FItems := e.ToArray;
  FCount := System.Length(FItems);
  if ElemCount > 0 then
    THelper.Sort(FItems);
end;

constructor TGBaseSortedList.Create(aRejectDuplicates: Boolean);
begin
  Create;
  FRejectDuplicates := aRejectDuplicates;
end;

constructor TGBaseSortedList.Create(const a: array of T; aRejectDuplicates: Boolean);
begin
  FRejectDuplicates := aRejectDuplicates;
  if RejectDuplicates then
    begin
      FItems := THelper.SelectDistinct(a);
      FCount := System.Length(FItems);
    end
  else
    Create(a);
end;

constructor TGBaseSortedList.Create(e: IEnumerable; aRejectDuplicates: Boolean);
begin
  FRejectDuplicates := aRejectDuplicates;
  if RejectDuplicates then
    begin
      FItems := THelper.SelectDistinct(e.ToArray);
      FCount := System.Length(FItems);
    end
  else
    Create(e);
end;

destructor TGBaseSortedList.Destroy;
begin
  DoClear;
  inherited;
end;

function TGBaseSortedList.Reverse: IEnumerable;
begin
  BeginIteration;
  Result := GetReverse;
end;

function TGBaseSortedList.ToArray: TArray;
begin
  Result := System.Copy(FItems, 0, ElemCount);
end;

function TGBaseSortedList.FindMin(out aValue: T): Boolean;
begin
  Result := ElemCount > 0;
  if Result then
    aValue := FItems[0];
end;

function TGBaseSortedList.FindMax(out aValue: T): Boolean;
begin
  Result := ElemCount > 0;
  if Result then
    aValue := FItems[Pred(ElemCount)];
end;

function TGBaseSortedList.Insert(const aValue: T): SizeInt;
begin
  CheckInIteration;
  Result := DoInsert(aValue);
end;

function TGBaseSortedList.Contains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) >= 0;
end;

procedure TGBaseSortedList.Delete(aIndex: SizeInt);
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  DeleteItem(aIndex);
end;

function TGBaseSortedList.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    DeleteItem(aIndex);
end;

function TGBaseSortedList.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DoDeleteRange(aIndex, aCount);
end;

function TGBaseSortedList.IndexOf(const aValue: T): SizeInt;
begin
  if ElemCount > 0 then
    Result := THelper.BinarySearch(FItems[0..Pred(ElemCount)], aValue)
  else
    Result := NULL_INDEX;
end;

function TGBaseSortedList.CountOf(const aValue: T): SizeInt;
var
  LastIdx, FirstIdx: SizeInt;
begin
  if ElemCount = 0 then //todo: ???
    exit(0);
  FirstIdx := THelper.BinarySearch(FItems[0..Pred(ElemCount)], aValue);
  if FirstIdx < 0 then
    exit(0);
  LastIdx := FirstIdx;
  while (LastIdx < Pred(ElemCount)) and not
        (TCmpRel.Less(aValue, FItems[Succ(LastIdx)]) or TCmpRel.Less(FItems[Succ(LastIdx)], aValue)) do
    Inc(LastIdx);
  Result := Succ(LastIdx - FirstIdx);
end;

function TGBaseSortedList.IndexOfCeil(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := LeftmostGE(aValue)
  else
    Result := LeftmostGT(aValue);
end;

function TGBaseSortedList.IndexOfFloor(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := RightmostLE(aValue)
  else
    Result := RightmostLT(aValue);
end;

function TGBaseSortedList.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(Self, IndexOfFloor(aHighBound, aInclusive));
end;

function TGBaseSortedList.Tail(const aLowBound: T; aInclusive: Boolean): IEnumerable;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    StartIdx := ElemCount;
  BeginIteration;
  Result := TTailEnumerable.Create(Self, StartIdx);
end;

function TGBaseSortedList.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(aLowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    StartIdx := ElemCount;
  BeginIteration;
  Result := TRangeEnumerable.Create(Self, StartIdx, IndexOfFloor(aHighBound, rbHigh in aIncludeBounds));
end;

function TGBaseSortedList.HeadList(const aHighBound: T; aInclusive: Boolean): TGBaseSortedList;
var
  HeadCount: SizeInt;
begin
  HeadCount := Succ(IndexOfFloor(aHighBound, aInclusive));
  if HeadCount = 0 then
    exit(TGBaseSortedList.Create(RejectDuplicates));
  Result := TGBaseSortedList.Create(HeadCount);
  Result.RejectDuplicates := RejectDuplicates;
  Result.FCount := HeadCount;
  THelper.CopyItems(@FItems[0], @Result.FItems[0], HeadCount);
end;

function TGBaseSortedList.TailList(const aLowBound: T; aInclusive: Boolean): TGBaseSortedList;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    exit(TGBaseSortedList.Create(RejectDuplicates));
  Result := TGBaseSortedList.Create(ElemCount - StartIdx);
  Result.RejectDuplicates := RejectDuplicates;
  Result.FCount := ElemCount - StartIdx;
  THelper.CopyItems(@FItems[StartIdx], @Result.FItems[0], ElemCount - StartIdx);
end;

function TGBaseSortedList.SubList(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TGBaseSortedList;
var
  StartIdx, LastIdx, RangeCount: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    exit(TGBaseSortedList.Create(RejectDuplicates));
  LastIdx := IndexOfFloor(aHighBound, rbHigh in aIncludeBounds);
  if LastIdx < StartIdx then
    exit(TGBaseSortedList.CreateEmpty);
  RangeCount := Succ(LastIdx - StartIdx);
  Result := TGBaseSortedList.Create(RangeCount);
  Result.RejectDuplicates := RejectDuplicates;
  Result.FCount := RangeCount;
  THelper.CopyItems(@FItems[StartIdx], @Result.FItems[0], RangeCount);
end;

function TGBaseSortedList.Clone: TGBaseSortedList;
begin
  Result := TGBaseSortedList.CreateEmpty;
  //Result.FItems := System.Copy(FItems, 0, ListCapacity);
  Result.FItems := ToArray; ///////////////
  Result.FCount := ElemCount;
  Result.FRejectDuplicates := RejectDuplicates;
end;

{ TGSortedList2.TEnumerator }

function TGSortedList2.TEnumerator.GetCurrent: T;
begin
  Result := FList[FCurrIndex];
end;

constructor TGSortedList2.TEnumerator.Create(aList: TGSortedList2);
begin
  FList := aList.FItems;
  FLastIndex := Pred(aList.Count);
  FCurrIndex := NULL_INDEX;
end;

function TGSortedList2.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLastIndex;
  FCurrIndex += Ord(Result);
end;

procedure TGSortedList2.TEnumerator.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGSortedList2 }

function TGSortedList2.GetCapacity: SizeInt;
begin
  Result := System.Length(FItems);
end;

procedure TGSortedList2.Expand(aValue: SizeInt);
begin
  //there aValue > Capacity
  if aValue <= DEFAULT_CONTAINER_CAPACITY then
    System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY)
  else
    if aValue <= MAX_CONTAINER_SIZE div SizeOf(T) then
      begin
        aValue := Math.Min(MAX_CONTAINER_SIZE div SizeOf(T), LGUtils.RoundUpTwoPower(aValue));
        System.SetLength(FItems, aValue);
      end
    else
      CapacityExceedError(aValue);
end;

procedure TGSortedList2.ItemAdding;
begin
  if Count = Capacity then
    Expand(Succ(Count));
end;

procedure TGSortedList2.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  ItemAdding;
  if aIndex < Count then
    begin
      System.Move(FItems[aIndex], FItems[Succ(aIndex)], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FItems[aIndex], SizeOf(T), 0);
    end;
  FItems[aIndex] := aValue;
  Inc(FCount);
end;

procedure TGSortedList2.RemoveItem(aIndex: SizeInt);
begin
  FItems[aIndex] := Default(T);
  Dec(FCount);
  System.Move(FItems[Succ(aIndex)], FItems[aIndex], SizeOf(T) * (Count - aIndex));
  if IsManagedType(T) then
    System.FillChar(FItems[Count], SizeOf(T), 0);
end;

procedure TGSortedList2.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SEClassCapacityExceedFmt, [ClassName, aValue]);
end;

constructor TGSortedList2.CreateEmpty;
begin
  inherited Create;
end;

constructor TGSortedList2.CreateEmpty(aAllowDuplicates: Boolean);
begin
  inherited Create;
  FAllowDuplicates := aAllowDuplicates;
end;

constructor TGSortedList2.Create;
begin
  System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY);
end;

constructor TGSortedList2.Create(aCapacity: SizeInt);
begin
  if aCapacity < 0 then
    aCapacity := 0;
  if aCapacity <= MAX_CONTAINER_SIZE div SizeOf(T) then
    System.SetLength(FItems, aCapacity)
  else
    CapacityExceedError(aCapacity);
end;

constructor TGSortedList2.Create(aCapacity: SizeInt; aAllowDuplicates: Boolean);
begin
  Create(aCapacity);
  FAllowDuplicates := aAllowDuplicates;
end;

destructor TGSortedList2.Destroy;
begin
  Clear;
  inherited;
end;

function TGSortedList2.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGSortedList2.Clear;
begin
  FItems := nil;
  FCount := 0;
  FAllowDuplicates := False;
end;

function TGSortedList2.EnsureCapacity(aValue: SizeInt): Boolean;
begin
  try
    if aValue > Capacity then
      Expand(aValue);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TGSortedList2.TrimToFit;
begin
  System.SetLength(FItems, Count);
end;

function TGSortedList2.Add(const aValue: T): Boolean;
var
  sr: TSearchResult;
begin
  if Count > 0 then
    begin
      sr := THelper.BinarySearchPos(FItems[0..Pred(Count)], aValue);
      if (sr.FoundIndex >= 0) and not AllowDuplicates then
        exit(False);
      InsertItem(sr.InsertIndex, aValue);
    end
  else
    InsertItem(Count, aValue);
  Result := True;
end;

function TGSortedList2.Contains(const aValue: T): Boolean;
begin
  if Count > 0 then
    Result := THelper.BinarySearch(FItems[0..Pred(Count)], aValue) >= 0
  else
    Result := False;
end;

function TGSortedList2.Remove(const aValue: T): Boolean;
var
  RemoveIdx: SizeInt;
begin
  if Count > 0 then
    begin
      RemoveIdx := THelper.BinarySearch(FItems[0..Pred(Count)], aValue);
      Result := RemoveIdx >= 0;
      if Result then
        RemoveItem(RemoveIdx);
    end
  else
    Result := False;
end;

{ TGSortedListTable.TEntryCmpRel }

class function TGSortedListTable.TEntryCmpRel.Less(const L, R: TEntry): Boolean;
begin
  Result := TCmpRel.Less(L.Key, R.Key);
end;

{ TGSortedListTable.TEnumerator }

function TGSortedListTable.TEnumerator.GetCurrent: PEntry;
begin
  Result := @FList[FCurrIndex];
end;

constructor TGSortedListTable.TEnumerator.Create(aTable: TGSortedListTable);
begin
  FList := aTable.FItems;
  FLastIndex := Pred(aTable.Count);
  FCurrIndex := NULL_INDEX;
end;

function TGSortedListTable.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLastIndex;
  FCurrIndex += Ord(Result);
end;

procedure TGSortedListTable.TEnumerator.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGSortedListTable }

function TGSortedListTable.GetCapacity: SizeInt;
begin
  Result := System.Length(FItems);
end;

procedure TGSortedListTable.Expand(aValue: SizeInt);
begin
  //there aValue > Capacity
  if aValue <= DEFAULT_CONTAINER_CAPACITY then
    System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY)
  else
    if aValue <= MAX_CONTAINER_SIZE div SizeOf(TEntry) then
      begin
        aValue := Math.Min(MAX_CONTAINER_SIZE div SizeOf(TEntry), LGUtils.RoundUpTwoPower(aValue));
        System.SetLength(FItems, aValue);
      end
    else
      CapacityExceedError(aValue);
end;

procedure TGSortedListTable.ItemAdding;
begin
  if Count = Capacity then
    Expand(Succ(Count));
end;

procedure TGSortedListTable.InsertItem(aIndex: SizeInt; constref aValue: TEntry);
begin
  ItemAdding;
  if aIndex < Count then
    begin
      System.Move(FItems[aIndex], FItems[Succ(aIndex)], SizeOf(TEntry) * (Count - aIndex));
      if IsManagedType(TEntry) then
        System.FillChar(FItems[aIndex], SizeOf(TEntry), 0);
    end;
  FItems[aIndex] := aValue;
  Inc(FCount);
end;

procedure TGSortedListTable.RemoveItem(aIndex: SizeInt);
begin
  FItems[aIndex] := Default(TEntry);
  Dec(FCount);
  System.Move(FItems[Succ(aIndex)], FItems[aIndex], SizeOf(TEntry) * (Count - aIndex));
  if IsManagedType(TEntry) then
    System.FillChar(FItems[Count], SizeOf(TEntry), 0);
end;

procedure TGSortedListTable.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SEClassCapacityExceedFmt, [ClassName, aValue]);
end;

constructor TGSortedListTable.CreateEmpty;
begin
  inherited Create;
end;

constructor TGSortedListTable.CreateEmpty(aAllowDuplicates: Boolean);
begin
  inherited Create;
  FAllowDuplicates := aAllowDuplicates;
end;

constructor TGSortedListTable.Create;
begin
  System.SetLength(FItems, DEFAULT_CONTAINER_CAPACITY);
end;

constructor TGSortedListTable.Create(aCapacity: SizeInt);
begin
  if aCapacity <= MAX_CONTAINER_SIZE div SizeOf(TEntry) then
    begin
      if aCapacity < 0 then
        aCapacity := 0;
      System.SetLength(FItems, aCapacity);
    end
  else
    CapacityExceedError(aCapacity);
end;

constructor TGSortedListTable.Create(aCapacity: SizeInt; aAllowDuplicates: Boolean);
begin
  Create(aCapacity);
  FAllowDuplicates := aAllowDuplicates;
end;

destructor TGSortedListTable.Destroy;
begin
  Clear;
  inherited;
end;

function TGSortedListTable.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGSortedListTable.Clear;
begin
  FItems := nil;
  FCount := 0;
end;

function TGSortedListTable.EnsureCapacity(aValue: SizeInt): Boolean;
begin
  try
    if aValue > Capacity then
      Expand(aValue);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TGSortedListTable.TrimToFit;
begin
  System.SetLength(FItems, Count);
end;

function TGSortedListTable.FindOrAdd(const aKey: TKey; out e: PEntry; out aPos: SizeInt): Boolean;
var
  sr: TSearchResult;
  Entry: TEntry;
begin
  Entry.Key := aKey;
  if Count > 0 then
    begin
      sr := specialize TGBaseArrayHelper<TEntry, TEntryCmpRel>.BinarySearchPos(FItems[0..Pred(Count)], Entry);
      Result := sr.FoundIndex >= 0;
      if Result then
        aPos := sr.FoundIndex
      else
        begin
          aPos := sr.InsertIndex;
          InsertItem(aPos, Entry);
        end;
    end
  else
    begin
      Result := False;
      aPos := 0;
      InsertItem(aPos, Entry);
    end;
  e := @FItems[aPos];
end;

function TGSortedListTable.Find(const aKey: TKey; out aPos: SizeInt): PEntry;
var
  e: TEntry;
begin
  Result := nil;
  if Count > 0 then
    begin
      e.Key := aKey;
      aPos := specialize TGBaseArrayHelper<TEntry, TEntryCmpRel>.BinarySearch(FItems[0..Pred(Count)], e);
      if aPos >= 0 then
        Result := @FItems[aPos];
    end;
end;

function TGSortedListTable.Add(const aKey: TKey): PEntry;
var
  sr: TSearchResult;
  Entry: TEntry;
begin
  Result := nil;
  Entry.Key := aKey;
  if Count > 0 then
    begin
      sr := specialize TGBaseArrayHelper<TEntry, TEntryCmpRel>.BinarySearchPos(FItems[0..Pred(Count)], Entry);
      if (sr.FoundIndex < 0) or AllowDuplicates then
        begin
          InsertItem(sr.InsertIndex, Entry);
          Result := @FItems[sr.InsertIndex];
        end;
    end
  else
    begin
      InsertItem(0, Entry);
      Result := @FItems[0];
    end;
end;

function TGSortedListTable.Remove(const aKey: TKey): Boolean;
var
  e: TEntry;
  RemoveIdx: SizeInt;
begin
  e.Key := aKey;
  RemoveIdx := specialize TGBaseArrayHelper<TEntry, TEntryCmpRel>.BinarySearch(FItems[0..Pred(Count)], e);
  Result := RemoveIdx >= 0;
  if Result then
    RemoveItem(RemoveIdx);
end;

procedure TGSortedListTable.RemoveAt(aIndex: SizeInt);
begin
  if (aIndex >= 0) and (aIndex < Count) then
    RemoveItem(aIndex);
end;

{ TGLiteSortedList.THeadEnumerator }

function TGLiteSortedList.THeadEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGLiteSortedList.THeadEnumerator.Create(const aList: TGLiteSortedList; aLastIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := aLastIndex;
  FCurrIndex := NULL_INDEX;
end;

function TGLiteSortedList.THeadEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

{ TGLiteSortedList.THead }

constructor TGLiteSortedList.THead.Create(aList: PLiteSortedList; aHighBound: SizeInt);
begin
  FList := aList;
  FHighBound := aHighBound;
end;

function TGLiteSortedList.THead.GetEnumerator: THeadEnumerator;
begin
  Result := FList^.GetHeadEnumerator(FHighBound);
end;

{ TGLiteSortedList.TTailEnumerator }

function TGLiteSortedList.TTailEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGLiteSortedList.TTailEnumerator.Create(const aList: TGLiteSortedList; aStartIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := Pred(aList.Count);
  FStart := Pred(aStartIndex);
  FCurrIndex := FStart;
end;

constructor TGLiteSortedList.TTailEnumerator.Create(const aList: TGLiteSortedList; aStartIndex,
  aLastIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := aLastIndex;
  FStart := Pred(aStartIndex);
  FCurrIndex := FStart;
end;

function TGLiteSortedList.TTailEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

{ TGLiteSortedList.TTail }

constructor TGLiteSortedList.TTail.Create(aList: PLiteSortedList; aLowBound: SizeInt);
begin
  FList := aList;
  FLowBound := aLowBound;
end;

function TGLiteSortedList.TTail.GetEnumerator: TTailEnumerator;
begin
  Result := FList^.GetTailEnumerator(FLowBound);
end;

{ TGLiteSortedList.TRange }

constructor TGLiteSortedList.TRange.Create(aList: PLiteSortedList; aLowBound, aHighBound: SizeInt);
begin
  FList := aList;
  FLowBound := aLowBound;
  FHighBound := aHighBound;
end;

function TGLiteSortedList.TRange.GetEnumerator: TTailEnumerator;
begin
  Result := FList^.GetRangeEnumerator(FLowBound, FHighBound);
end;

{ TGLiteSortedList }

function TGLiteSortedList.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteSortedList.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteSortedList.SetItem(aIndex: SizeInt; aValue: T);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DoSetItem(aIndex, aValue)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteSortedList.DoSetItem(aIndex: SizeInt; const aValue: T);
var
  sr: TSearchResult;
begin
  if TCmpRel.Less(aValue, FBuffer.FItems[aIndex]) or TCmpRel.Less(FBuffer.FItems[aIndex], aValue) then
    begin
      if Count > 1 then
        begin
          sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
          if (sr.FoundIndex >= 0) and RejectDuplicates then
            exit;
          FBuffer.FItems[aIndex] := Default(T);  ///////////////
          if sr.InsertIndex > aIndex then
            System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], sr.InsertIndex - aIndex)
          else
            System.Move(FBuffer.FItems[sr.InsertIndex], FBuffer.FItems[Succ(sr.InsertIndex)], aIndex - sr.InsertIndex);
          if IsManagedType(T) then
            System.FillChar(FBuffer.FItems[sr.InsertIndex], SizeOf(T), 0);
          FBuffer.FItems[sr.InsertIndex] := aValue;
        end;
    end
  else
    FBuffer.FItems[aIndex] := aValue;
end;

procedure TGLiteSortedList.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  FBuffer.ItemAdding;
  if aIndex < Count then
    begin
      System.Move(FBuffer.FItems[aIndex], FBuffer.FItems[Succ(aIndex)], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[aIndex], SizeOf(T), 0);
    end;
  FBuffer.FItems[aIndex] := aValue;
  Inc(FBuffer.FCount);
end;

function TGLiteSortedList.ExtractItem(aIndex: SizeInt): T;
begin
  Result := FBuffer.FItems[aIndex];
  FBuffer.FItems[aIndex] := Default(T);
  Dec(FBuffer.FCount);
  System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
  if IsManagedType(T) then
    System.FillChar(FBuffer.FItems[Count], SizeOf(T), 0);
end;

function TGLiteSortedList.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

procedure TGLiteSortedList.RemoveDuplicates;
var
  I, J, Hi: SizeInt;
begin
  Hi := Pred(Count);
  if Hi < 1 then
    exit;
  I := 0;
  for J := 1 to Hi do
    begin
      if not(TCmpRel.Less(FBuffer.FItems[I], FBuffer.FItems[J]) or
             TCmpRel.Less(FBuffer.FItems[J], FBuffer.FItems[I])) then
        continue;
      Inc(I);
      if J > I then
        FBuffer.FItems[I] := FBuffer.FItems[J];
    end;
  FBuffer.FCount := Succ(I);
  if IsManagedType(T) then
    for I := Count to Hi do
      FBuffer.FItems[I] := Default(T);
end;

procedure TGLiteSortedList.SetRejectDuplicates(aValue: Boolean);
begin
  if RejectDuplicates <> aValue then
    begin
      FRejectDuplicates := aValue;
      if RejectDuplicates then
        RemoveDuplicates;
    end;
end;

function TGLiteSortedList.RightmostLT(const aValue: T): SizeInt;
begin
  if IsEmpty or not TCmpRel.Less(FBuffer.FItems[0], aValue) then
    exit(NULL_INDEX);
  if TCmpRel.Less(FBuffer.FItems[Pred(Count)], aValue) then
     exit(Pred(Count));
  Result := THelper.BiSearchLeftA(@FBuffer.FItems[0], Pred(Count), aValue);
  if not(TCmpRel.Less(FBuffer.FItems[Result], aValue) or TCmpRel.Less(aValue, FBuffer.FItems[Result])) then
    Dec(Result);
end;

function TGLiteSortedList.RightmostLE(const aValue: T): SizeInt;
begin
  if IsEmpty or TCmpRel.Less(aValue, FBuffer.FItems[0]) then
    exit(NULL_INDEX);
  if not TCmpRel.Less(aValue, FBuffer.FItems[Pred(Count)]) then
    exit(Pred(Count));
  Result := THelper.BiSearchRightA(@FBuffer.FItems[0], Pred(Count), aValue);
  if TCmpRel.Less(aValue, FBuffer.FItems[Result]) then
    Dec(Result);
end;

function TGLiteSortedList.LeftmostGT(const aValue: T): SizeInt;
begin
  if IsEmpty or not TCmpRel.Less(aValue, FBuffer.FItems[Pred(Count)]) then
    exit(NULL_INDEX);
  if TCmpRel.Less(aValue, FBuffer.FItems[0]) then
    exit(0);
  Result := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue).InsertIndex;
end;

function TGLiteSortedList.LeftmostGE(const aValue: T): SizeInt;
begin
  if (Count = 0) or TCmpRel.Less(FBuffer.FItems[Pred(Count)], aValue) then
    exit(NULL_INDEX);
  if not TCmpRel.Less(FBuffer.FItems[0], aValue) then
    exit(0);
  Result := THelper.BiSearchLeftA(@FBuffer.FItems[0], Pred(Count), aValue);
end;

function TGLiteSortedList.SelectDistinctArray(const a: array of T): TArray;
var
  I, J, Hi: SizeInt;
begin
  Result := THelper.SelectDistinct(a);
  if IsEmpty then
    exit;
  Hi := System.High(Result);
  I := NULL_INDEX;
  for J := 0 to Hi do
    begin
      if IndexOf(Result[J]) >= 0 then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

function TGLiteSortedList.GetHeadEnumerator(aHighBound: SizeInt): THeadEnumerator;
begin
  Result := THeadEnumerator.Create(Self, aHighBound);
end;

function TGLiteSortedList.GetTailEnumerator(aLowBound: SizeInt): TTailEnumerator;
begin
  Result := TTailEnumerator.Create(Self, aLowBound);
end;

function TGLiteSortedList.GetRangeEnumerator(aLowBound, aHighBound: SizeInt): TTailEnumerator;
begin
  Result := TTailEnumerator.Create(Self, aLowBound, aHighBound);
end;

class operator TGLiteSortedList.Initialize(var lst: TGLiteSortedList);
begin
  lst.RejectDuplicates := False;
end;

function TGLiteSortedList.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteSortedList.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteSortedList.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteSortedList.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteSortedList.Clear;
begin
  FBuffer.Clear;
end;

function TGLiteSortedList.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteSortedList.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteSortedList.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteSortedList.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

function TGLiteSortedList.FindMin(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[0];
end;

function TGLiteSortedList.FindMax(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[Pred(FBuffer.Count)];
end;

function TGLiteSortedList.FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      Result := sr.FoundIndex >= 0;
      if Result then
        aIndex := sr.FoundIndex;
    end
  else
    begin
      sr.InsertIndex := 0;
      Result := False;
    end;
  if not Result then
    begin
      aIndex := sr.InsertIndex;
      InsertItem(aIndex, aValue);
    end;
end;

function TGLiteSortedList.Add(const aValue: T): Boolean;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(False);
      InsertItem(sr.InsertIndex, aValue);
    end
  else
    InsertItem(Count, aValue);
  Result := True;
end;

function TGLiteSortedList.AddAll(const a: array of T): SizeInt;
var
  OldCount: SizeInt;
  PSrc: PItem;
  da: TArray;
begin
  OldCount := Count;
  if RejectDuplicates then
    begin
      da := SelectDistinctArray(a);
      Result := System.Length(da);
      if Result = 0 then
        exit;
      PSrc := @da[0];
    end
  else
    begin
      Result := System.Length(a);
      if Result = 0 then
        exit;
      PSrc := @a[0];
    end;
  EnsureCapacity(OldCount + Result);
  THelper.CopyItems(PSrc, @FBuffer.FItems[OldCount], Result);
  FBuffer.FCount += Result;
  if RejectDuplicates or (OldCount >= Result) then
    THelper.MergeSort(FBuffer.FItems[0..Pred(Count)])
  else
    THelper.Sort(FBuffer.FItems[0..Pred(Count)])
end;

function TGLiteSortedList.Remove(const aValue: T): Boolean;
var
  ToRemove: SizeInt;
begin
  ToRemove := IndexOf(aValue);
  Result := ToRemove >= 0;
  if Result then
    DeleteItem(ToRemove);
end;

function TGLiteSortedList.Insert(const aValue: T): SizeInt;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(NULL_INDEX);
      Result := sr.InsertIndex;
    end
  else
    Result := 0;
  InsertItem(Result, aValue);
end;

function TGLiteSortedList.Contains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) >= 0;
end;

function TGLiteSortedList.NonContains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) < 0;
end;

procedure TGLiteSortedList.Delete(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DeleteItem(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteSortedList.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := SizeUInt(aIndex) < SizeUInt(Count);
  if Result then
    DeleteItem(aIndex);
end;

function TGLiteSortedList.IndexOf(const aValue: T): SizeInt;
begin
  if NonEmpty then
    Result := THelper.BinarySearch(FBuffer.FItems[0..Pred(Count)], aValue)
  else
    Result := NULL_INDEX;
end;

function TGLiteSortedList.CountOf(const aValue: T): SizeInt;
var
  LastIdx, FirstIdx: SizeInt;
begin
  if IsEmpty then  //todo: ???
    exit(0);
  FirstIdx := THelper.BinarySearch(FBuffer.FItems[0..Pred(Count)], aValue);
  if FirstIdx < 0 then
    exit(0);
  LastIdx := FirstIdx;
  while (LastIdx < Pred(Count)) and not
        (TCmpRel.Less(aValue, FBuffer.FItems[Succ(LastIdx)]) or
         TCmpRel.Less(FBuffer.FItems[Succ(LastIdx)], aValue)) do
    Inc(LastIdx);
  Result := Succ(LastIdx - FirstIdx);
end;

function TGLiteSortedList.IndexOfCeil(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := LeftmostGE(aValue)
  else
    Result := LeftmostGT(aValue);
end;

function TGLiteSortedList.IndexOfFloor(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := RightmostLE(aValue)
  else
    Result := RightmostLT(aValue);
end;

function TGLiteSortedList.Head(const aHighBound: T; aInclusive: Boolean): THead;
begin
  Result := THead.Create(@Self, IndexOfFloor(aHighBound, aInclusive));
end;

function TGLiteSortedList.Tail(const aLowBound: T; aInclusive: Boolean): TTail;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    StartIdx := Count;
  Result := TTail.Create(@Self, StartIdx);
end;

function TGLiteSortedList.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TRange;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(aLowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    StartIdx := Count;
  Result := TRange.Create(@Self, StartIdx, IndexOfFloor(aHighBound, rbHigh in aIncludeBounds));
end;

function TGLiteSortedList.HeadList(const aHighBound: T; aInclusive: Boolean): TGLiteSortedList;
var
  HeadCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  HeadCount := Succ(IndexOfFloor(aHighBound, aInclusive));
  if HeadCount = 0 then
    exit;
  Result.EnsureCapacity(HeadCount);
  Result.FBuffer.FCount := HeadCount;
  THelper.CopyItems(@FBuffer.FItems[0], @Result.FBuffer.FItems[0], HeadCount);
end;

function TGLiteSortedList.TailList(const aLowBound: T; aInclusive: Boolean): TGLiteSortedList;
var
  StartIdx, TailCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    exit;
  TailCount := Count - StartIdx;
  Result.EnsureCapacity(TailCount);
  Result.FBuffer.FCount := TailCount;
  THelper.CopyItems(@FBuffer.FItems[StartIdx], @Result.FBuffer.FItems[0], TailCount);
end;

function TGLiteSortedList.SubList(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGLiteSortedList;
var
  StartIdx, LastIdx, RangeCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  StartIdx := IndexOfCeil(ALowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    exit;
  LastIdx := IndexOfFloor(aHighBound, rbHigh in aIncludeBounds);
  if LastIdx < StartIdx then
    exit;
  RangeCount := Succ(LastIdx - StartIdx);
  Result.EnsureCapacity(RangeCount);
  Result.FBuffer.FCount := RangeCount;
  THelper.CopyItems(@FBuffer.FItems[StartIdx], @Result.FBuffer.FItems[0], RangeCount);
end;

{ TGLiteComparableSortedList.THeadEnumerator }

function TGLiteComparableSortedList.THeadEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGLiteComparableSortedList.THeadEnumerator.Create(constref aList: TSortedList; aLastIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := aLastIndex;
  FCurrIndex := NULL_INDEX;
end;

function TGLiteComparableSortedList.THeadEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

{ TGLiteComparableSortedList.THead }

constructor TGLiteComparableSortedList.THead.Create(aList: PSortedList; aHighBound: SizeInt);
begin
  FList := aList;
  FHighBound := aHighBound;
end;

function TGLiteComparableSortedList.THead.GetEnumerator: THeadEnumerator;
begin
  Result := FList^.GetHeadEnumerator(FHighBound);
end;

{ TGLiteComparableSortedList.TTailEnumerator }

function TGLiteComparableSortedList.TTailEnumerator.GetCurrent: T;
begin
  Result := FItems[FCurrIndex];
end;

constructor TGLiteComparableSortedList.TTailEnumerator.Create(const aList: TSortedList; aStartIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := Pred(aList.Count);
  FStart := Pred(aStartIndex);
  FCurrIndex := FStart;
end;

constructor TGLiteComparableSortedList.TTailEnumerator.Create(const aList: TSortedList; aStartIndex,
  aLastIndex: SizeInt);
begin
  FItems := aList.FBuffer.FItems;
  FLast := aLastIndex;
  FStart := Pred(aStartIndex);
  FCurrIndex := FStart;
end;

function TGLiteComparableSortedList.TTailEnumerator.MoveNext: Boolean;
begin
  Result := FCurrIndex < FLast;
  FCurrIndex += Ord(Result);
end;

{ TGLiteComparableSortedList.TTail }

constructor TGLiteComparableSortedList.TTail.Create(aList: PSortedList; aLowBound: SizeInt);
begin
  FList := aList;
  FLowBound := aLowBound;
end;

function TGLiteComparableSortedList.TTail.GetEnumerator: TTailEnumerator;
begin
  Result := FList^.GetTailEnumerator(FLowBound);
end;

{ TGLiteComparableSortedList.TRange }

constructor TGLiteComparableSortedList.TRange.Create(aList: PSortedList; aLowBound, aHighBound: SizeInt);
begin
  FList := aList;
  FLowBound := aLowBound;
  FHighBound := aHighBound;
end;

function TGLiteComparableSortedList.TRange.GetEnumerator: TTailEnumerator;
begin
  Result := FList^.GetRangeEnumerator(FLowBound, FHighBound);
end;

{ TGLiteComparableSortedList }

function TGLiteComparableSortedList.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteComparableSortedList.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteComparableSortedList.SetItem(aIndex: SizeInt; aValue: T);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DoSetItem(aIndex, aValue)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteComparableSortedList.DoSetItem(aIndex: SizeInt; const aValue: T);
var
  sr: TSearchResult;
begin
  if THelper.ValNotEqual(aValue, FBuffer.FItems[aIndex]) then
    begin
      if Count > 1 then
        begin
          sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
          if (sr.FoundIndex >= 0) and RejectDuplicates then
            exit;
          FBuffer.FItems[aIndex] := Default(T);  ///////////////
          if sr.InsertIndex > aIndex then
            System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], sr.InsertIndex - aIndex)
          else
            System.Move(FBuffer.FItems[sr.InsertIndex], FBuffer.FItems[Succ(sr.InsertIndex)], aIndex - sr.InsertIndex);
          if IsManagedType(T) then
            System.FillChar(FBuffer.FItems[sr.InsertIndex], SizeOf(T), 0);
          FBuffer.FItems[sr.InsertIndex] := aValue;
        end;
    end
  else
    FBuffer.FItems[aIndex] := aValue;
end;

procedure TGLiteComparableSortedList.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  FBuffer.ItemAdding;
  if aIndex < Count then
    begin
      System.Move(FBuffer.FItems[aIndex], FBuffer.FItems[Succ(aIndex)], SizeOf(T) * (Count - aIndex));
      if IsManagedType(T) then
        System.FillChar(FBuffer.FItems[aIndex], SizeOf(T), 0);
    end;
  FBuffer.FItems[aIndex] := aValue;
  Inc(FBuffer.FCount);
end;

function TGLiteComparableSortedList.ExtractItem(aIndex: SizeInt): T;
begin
  Result := FBuffer.FItems[aIndex];
  FBuffer.FItems[aIndex] := Default(T);
  Dec(FBuffer.FCount);
  System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
  if IsManagedType(T) then
    System.FillChar(FBuffer.FItems[Count], SizeOf(T), 0);
end;

function TGLiteComparableSortedList.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

procedure TGLiteComparableSortedList.RemoveDuplicates;
var
  I, J, Hi: SizeInt;
begin
  Hi := Pred(Count);
  if Hi < 1 then
    exit;
  I := 0;
  for J := 1 to Hi do
    begin
      if THelper.ValEqual(FBuffer.FItems[I], FBuffer.FItems[J]) then
        continue;
      Inc(I);
      if J > I then
        FBuffer.FItems[I] := FBuffer.FItems[J];
    end;
  FBuffer.FCount := Succ(I);
  if IsManagedType(T) then
    for I := Count to Hi do
      FBuffer.FItems[I] := Default(T);
end;

procedure TGLiteComparableSortedList.SetRejectDuplicates(aValue: Boolean);
begin
  if RejectDuplicates <> aValue then
    begin
      FRejectDuplicates := aValue;
      if RejectDuplicates then
        RemoveDuplicates;
    end;
end;

function TGLiteComparableSortedList.RightmostLT(const aValue: T): SizeInt;
begin
  if IsEmpty or not(FBuffer.FItems[0] < aValue) then
    exit(NULL_INDEX);
  if FBuffer.FItems[Pred(Count)] < aValue then
     exit(Pred(Count));
  Result := THelper.BiSearchLeftA(@FBuffer.FItems[0], Pred(Count), aValue);
  if THelper.ValEqual(FBuffer.FItems[Result], aValue) then
    Dec(Result);
end;

function TGLiteComparableSortedList.RightmostLE(const aValue: T): SizeInt;
begin
  if IsEmpty or (aValue < FBuffer.FItems[0]) then
    exit(NULL_INDEX);
  if not(aValue < FBuffer.FItems[Pred(Count)]) then
    exit(Pred(Count));
  Result := THelper.BiSearchRightA(@FBuffer.FItems[0], Pred(Count), aValue);
  if aValue < FBuffer.FItems[Result] then
    Dec(Result);
end;

function TGLiteComparableSortedList.LeftmostGT(const aValue: T): SizeInt;
begin
  if IsEmpty or not(aValue < FBuffer.FItems[Pred(Count)]) then
    exit(NULL_INDEX);
  if aValue < FBuffer.FItems[0] then
    exit(0);
  Result := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue).InsertIndex;
end;

function TGLiteComparableSortedList.LeftmostGE(const aValue: T): SizeInt;
begin
  if (Count = 0) or (FBuffer.FItems[Pred(Count)] < aValue) then
    exit(NULL_INDEX);
  if not(FBuffer.FItems[0] < aValue) then
    exit(0);
  Result := THelper.BiSearchLeftA(@FBuffer.FItems[0], Pred(Count), aValue);
end;

function TGLiteComparableSortedList.SelectDistinctArray(const a: array of T): TArray;
var
  I, J, Hi: SizeInt;
begin
  Result := THelper.SelectDistinct(a);
  if IsEmpty then
    exit;
  Hi := System.High(Result);
  I := NULL_INDEX;
  for J := 0 to Hi do
    begin
      if IndexOf(Result[J]) >= 0 then
        continue;
      Inc(I);
      if J > I then
        Result[I] := Result[J];
    end;
  System.SetLength(Result, Succ(I));
end;

function TGLiteComparableSortedList.GetHeadEnumerator(aHighBound: SizeInt): THeadEnumerator;
begin
  Result := THeadEnumerator.Create(Self, aHighBound);
end;

function TGLiteComparableSortedList.GetTailEnumerator(aLowBound: SizeInt): TTailEnumerator;
begin
  Result := TTailEnumerator.Create(Self, aLowBound);
end;

function TGLiteComparableSortedList.GetRangeEnumerator(aLowBound, aHighBound: SizeInt): TTailEnumerator;
begin
  Result := TTailEnumerator.Create(Self, aLowBound, aHighBound);
end;

class operator TGLiteComparableSortedList.Initialize(var lst: TGLiteComparableSortedList);
begin
  lst.RejectDuplicates := False;
end;

function TGLiteComparableSortedList.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteComparableSortedList.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteComparableSortedList.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteComparableSortedList.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteComparableSortedList.Clear;
begin
  FBuffer.Clear;
end;

function TGLiteComparableSortedList.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteComparableSortedList.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteComparableSortedList.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteComparableSortedList.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

function TGLiteComparableSortedList.FindMin(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[0];
end;

function TGLiteComparableSortedList.FindMax(out aValue: T): Boolean;
begin
  Result := NonEmpty;
  if Result then
    aValue := FBuffer.FItems[Pred(FBuffer.Count)];
end;

function TGLiteComparableSortedList.FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      Result := sr.FoundIndex >= 0;
      if Result then
        aIndex := sr.FoundIndex;
    end
  else
    begin
      sr.InsertIndex := 0;
      Result := False;
    end;
  if not Result then
    begin
      aIndex := sr.InsertIndex;
      InsertItem(aIndex, aValue);
    end;
end;

function TGLiteComparableSortedList.Add(const aValue: T): Boolean;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(False);
      InsertItem(sr.InsertIndex, aValue);
    end
  else
    InsertItem(Count, aValue);
  Result := True;
end;

function TGLiteComparableSortedList.AddAll(const a: array of T): SizeInt;
var
  OldCount: SizeInt;
  PSrc: PItem;
  da: TArray;
begin
  OldCount := Count;
  if RejectDuplicates then
    begin
      da := SelectDistinctArray(a);
      Result := System.Length(da);
      if Result = 0 then
        exit;
      PSrc := @da[0];
    end
  else
    begin
      Result := System.Length(a);
      if Result = 0 then
        exit;
      PSrc := @a[0];
    end;
  EnsureCapacity(OldCount + Result);
  THelper.CopyItems(PSrc, @FBuffer.FItems[OldCount], Result);
  FBuffer.FCount += Result;
  if RejectDuplicates or (OldCount >= Result) then
    THelper.MergeSort(FBuffer.FItems[0..Pred(Count)])
  else
    THelper.Sort(FBuffer.FItems[0..Pred(Count)])
end;

function TGLiteComparableSortedList.Remove(const aValue: T): Boolean;
var
  ToRemove: SizeInt;
begin
  ToRemove := IndexOf(aValue);
  Result := ToRemove >= 0;
  if Result then
    DeleteItem(ToRemove);
end;

function TGLiteComparableSortedList.Insert(const aValue: T): SizeInt;
var
  sr: TSearchResult;
begin
  if NonEmpty then
    begin
      sr := THelper.BinarySearchPos(FBuffer.FItems[0..Pred(Count)], aValue);
      if (sr.FoundIndex >= 0) and RejectDuplicates then
        exit(NULL_INDEX);
      Result := sr.InsertIndex;
    end
  else
    Result := 0;
  InsertItem(Result, aValue);
end;

function TGLiteComparableSortedList.Contains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) >= 0;
end;

function TGLiteComparableSortedList.NonContains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) < 0;
end;

procedure TGLiteComparableSortedList.Delete(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DeleteItem(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteComparableSortedList.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := SizeUInt(aIndex) < SizeUInt(Count);
  if Result then
    DeleteItem(aIndex);
end;

function TGLiteComparableSortedList.IndexOf(const aValue: T): SizeInt;
begin
  if NonEmpty then
    Result := THelper.BinarySearch(FBuffer.FItems[0..Pred(Count)], aValue)
  else
    Result := NULL_INDEX;
end;

function TGLiteComparableSortedList.CountOf(const aValue: T): SizeInt;
var
  LastIdx, FirstIdx: SizeInt;
begin
  if IsEmpty then
    exit(0);
  FirstIdx := THelper.BinarySearch(FBuffer.FItems[0..Pred(Count)], aValue);
  if FirstIdx < 0 then
    exit(0);
  LastIdx := FirstIdx;
  while (LastIdx < Pred(Count)) and THelper.ValEqual(aValue, FBuffer.FItems[Succ(LastIdx)]) do
    Inc(LastIdx);
  Result := Succ(LastIdx - FirstIdx);
end;

function TGLiteComparableSortedList.IndexOfCeil(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := LeftmostGE(aValue)
  else
    Result := LeftmostGT(aValue);
end;

function TGLiteComparableSortedList.IndexOfFloor(const aValue: T; aInclusive: Boolean): SizeInt;
begin
  if aInclusive then
    Result := RightmostLE(aValue)
  else
    Result := RightmostLT(aValue);
end;

function TGLiteComparableSortedList.Head(const aHighBound: T; aInclusive: Boolean): THead;
begin
  Result := THead.Create(@Self, IndexOfFloor(aHighBound, aInclusive));
end;

function TGLiteComparableSortedList.Tail(const aLowBound: T; aInclusive: Boolean): TTail;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    StartIdx := Count;
  Result := TTail.Create(@Self, StartIdx);
end;

function TGLiteComparableSortedList.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): TRange;
var
  StartIdx: SizeInt;
begin
  StartIdx := IndexOfCeil(ALowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    StartIdx := Count;
  Result := TRange.Create(@Self, StartIdx, IndexOfFloor(aHighBound, rbHigh in aIncludeBounds));
end;

function TGLiteComparableSortedList.HeadList(const aHighBound: T; aInclusive: Boolean): TGLiteComparableSortedList;
var
  HeadCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  HeadCount := Succ(IndexOfFloor(aHighBound, aInclusive));
  if HeadCount = 0 then
    exit;
  Result.EnsureCapacity(HeadCount);
  Result.FBuffer.FCount := HeadCount;
  THelper.CopyItems(@FBuffer.FItems[0], @Result.FBuffer.FItems[0], HeadCount);
end;

function TGLiteComparableSortedList.TailList(const aLowBound: T; aInclusive: Boolean): TGLiteComparableSortedList;
var
  StartIdx, TailCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  StartIdx := IndexOfCeil(ALowBound, aInclusive);
  if StartIdx < 0 then
    exit;
  TailCount := Count - StartIdx;
  Result.EnsureCapacity(TailCount);
  Result.FBuffer.FCount := TailCount;
  THelper.CopyItems(@FBuffer.FItems[StartIdx], @Result.FBuffer.FItems[0], TailCount);
end;

function TGLiteComparableSortedList.SubList(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGLiteComparableSortedList;
var
  StartIdx, LastIdx, RangeCount: SizeInt;
begin
  Result.RejectDuplicates := RejectDuplicates;
  StartIdx := IndexOfCeil(ALowBound, rbLow in aIncludeBounds);
  if StartIdx < 0 then
    exit;
  LastIdx := IndexOfFloor(aHighBound, rbHigh in aIncludeBounds);
  if LastIdx < StartIdx then
    exit;
  RangeCount := Succ(LastIdx - StartIdx);
  Result.EnsureCapacity(RangeCount);
  Result.FBuffer.FCount := RangeCount;
  THelper.CopyItems(@FBuffer.FItems[StartIdx], @Result.FBuffer.FItems[0], RangeCount);
end;

{ TGLiteHashList.TEnumerator }

function TGLiteHashList.TEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

constructor TGLiteHashList.TEnumerator.Create(aList: PLiteHashList);
begin
  if aList^.Count > 0 then
    begin
      FCurrNode := PNode(aList^.FNodeList) - 1;
      FLastNode := FCurrNode + aList^.Count;
    end
  else
    begin
      FCurrNode := nil;
      FLastNode := nil;
    end;
end;

function TGLiteHashList.TEnumerator.MoveNext: Boolean;
begin
  if FCurrNode < FLastNode then
    begin
      Inc(FCurrNode);
      exit(True);
    end;
  Result := False;
end;

{ TGLiteHashList.TReverseEnumerator }

function TGLiteHashList.TReverseEnumerator.GetCurrent: T;
begin
  Result := FCurrNode^.Data;
end;

constructor TGLiteHashList.TReverseEnumerator.Create(aList: PLiteHashList);
begin
  if aList^.Count > 0 then
    begin
      FFirstNode := PNode(aList^.FNodeList);
      FCurrNode := FFirstNode + aList^.Count;
    end
  else
    begin
      FFirstNode := nil;
      FCurrNode := nil;
    end;
end;

function TGLiteHashList.TReverseEnumerator.MoveNext: Boolean;
begin
  if FCurrNode > FFirstNode then
    begin
      Dec(FCurrNode);
      exit(True);
    end;
  Result := False;
end;

{ TGLiteHashList.TReverse }

constructor TGLiteHashList.TReverse.Create(aList: PLiteHashList);
begin
  FList := aList;
end;

function TGLiteHashList.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result := TReverseEnumerator.Create(FList);
end;

{ TGLiteHashList }

function TGLiteHashList.GetCapacity: SizeInt;
begin
  Result := System.Length(FNodeList);
end;

function TGLiteHashList.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FNodeList[aIndex].Data
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteHashList.SetItem(aIndex: SizeInt; const aValue: T);
var
  I: SizeInt;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    begin
      if TEqRel.Equal(aValue, FNodeList[aIndex].Data) then
        exit;
      RemoveFromChain(aIndex);
      //add to new chain
      FNodeList[aIndex].Data := aValue;
      FNodeList[aIndex].Hash := TEqRel.HashCode(aValue);
      I := FNodeList[aIndex].Hash and Pred(Capacity);
      FNodeList[aIndex].Next := FChainList[I];
      FChainList[I] := aIndex;
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteHashList.InitialAlloc;
begin
  System.SetLength(FNodeList, DEFAULT_CONTAINER_CAPACITY);
  System.SetLength(FChainList, DEFAULT_CONTAINER_CAPACITY);
  System.FillChar(FChainList[0], DEFAULT_CONTAINER_CAPACITY * SizeOf(SizeInt), $ff);
end;

procedure TGLiteHashList.Rehash;
var
  I, J, Mask: SizeInt;
begin
  Mask := Pred(Capacity);
  System.FillChar(FChainList[0], Succ(Mask) * SizeOf(SizeInt), $ff);
  for I := 0 to Pred(Count) do
    begin
      J := FNodeList[I].Hash and Mask;
      FNodeList[I].Next := FChainList[J];
      FChainList[J] := I;
    end;
end;

procedure TGLiteHashList.Resize(aNewCapacity: SizeInt);
begin
  System.SetLength(FNodeList, aNewCapacity);
  System.SetLength(FChainList, aNewCapacity);
  Rehash;
end;

procedure TGLiteHashList.Expand;
var
  OldCapacity: SizeInt;
begin
  OldCapacity := Capacity;
  if OldCapacity > 0 then
    begin
      if OldCapacity < LGUtils.RoundUpTwoPower(MAX_CONTAINER_SIZE div SizeOf(TNode)) then
        Resize(OldCapacity shl 1)
      else
        CapacityExceedError(OldCapacity shl 1);
    end
  else
    InitialAlloc;
end;

function TGLiteHashList.Find(const aValue: T; aHash: SizeInt): SizeInt;
begin
  Result := FChainList[aHash and Pred(Capacity)];
  while Result <> NULL_INDEX do
    begin
      if (FNodeList[Result].Hash = aHash) and TEqRel.Equal(FNodeList[Result].Data, aValue) then
        exit;
      Result := FNodeList[Result].Next;
    end;
end;

function TGLiteHashList.Find(const aValue: T): SizeInt;
begin
  Result := Find(aValue, TEqRel.HashCode(aValue));
end;

function TGLiteHashList.GetCountOf(const aValue: T): SizeInt;
var
  h, I: SizeInt;
begin
  h := TEqRel.HashCode(aValue);
  I := FChainList[h and Pred(Capacity)];
  Result := 0;
  while I <> NULL_INDEX do
    begin
      if (FNodeList[I].Hash = h) and TEqRel.Equal(FNodeList[I].Data, aValue) then
        Inc(Result);
      I := FNodeList[I].Next;
    end;
end;

function TGLiteHashList.DoAdd(const aValue: T; aHash: SizeInt): SizeInt;
begin
  Result := Count;
  FNodeList[Result].Hash := aHash;
  FNodeList[Result].Data := aValue;
  FNodeList[Result].Next := FChainList[aHash and Pred(Capacity)];
  FChainList[aHash and Pred(Capacity)] := Result;
  Inc(FCount);
end;

function TGLiteHashList.DoAdd(const aValue: T): SizeInt;
begin
  Result := DoAdd(aValue, TEqRel.HashCode(aValue));
end;

procedure TGLiteHashList.DoInsert(aIndex: SizeInt; const aValue: T);
begin
  if aIndex < Count then
    begin
      System.Move(FNodeList[aIndex], FNodeList[Succ(aIndex)], (Count - aIndex) * SizeOf(TNode));
      if IsManagedType(T) then
        System.FillChar(FNodeList[aIndex].Data, SizeOf(T), 0);
      FNodeList[aIndex].Hash := TEqRel.HashCode(aValue);
      FNodeList[aIndex].Data := aValue;
      Inc(FCount);
      Rehash;
    end
  else
    DoAdd(aValue);
end;

procedure TGLiteHashList.DoDelete(aIndex: SizeInt);
begin
  Dec(FCount);
  if IsManagedType(T) then
    FNodeList[aIndex].Data := Default(T);
  if aIndex < Count then
    begin
      System.Move(FNodeList[Succ(aIndex)], FNodeList[aIndex], (Count - aIndex) * SizeOf(TNode));
      if IsManagedType(T) then
        System.FillChar(FNodeList[Count].Data, SizeOf(T), 0);
      Rehash;
    end
  else   // last element
    RemoveFromChain(aIndex);
end;

procedure TGLiteHashList.RemoveFromChain(aIndex: SizeInt);
var
  I, Curr, Prev: SizeInt;
begin
  I := FNodeList[aIndex].Hash and Pred(Capacity);
  Curr := FChainList[I];
  Prev := NULL_INDEX;
  while Curr <> NULL_INDEX do
    begin
      if Curr = aIndex then
        begin
          if Prev <> NULL_INDEX then
            FNodeList[Prev].Next := FNodeList[Curr].Next
          else
            FChainList[I] := FNodeList[Curr].Next;
          exit;
        end;
      Prev := Curr;
      Curr := FNodeList[Curr].Next;
    end;
end;

function TGLiteHashList.DoRemove(const aValue: T): Boolean;
var
  Removed: SizeInt;
begin
  Removed := Find(aValue);
  Result := Removed >= 0;
  if Result then
    DoDelete(Removed);
end;

function TGLiteHashList.FindOrAdd(const aValue: T; out aIndex: SizeInt): Boolean;
var
  h: SizeInt;
begin
  h := TEqRel.HashCode(aValue);
  if Count > 0 then
    aIndex := Find(aValue, h)
  else
    aIndex := NULL_INDEX;
  Result := aIndex >= 0;
  if not Result then
    begin
      if Count = Capacity then
        Expand;
      aIndex := DoAdd(aValue, h);
    end;
end;

class procedure TGLiteHashList.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SECapacityExceedFmt, [aValue]);
end;

class operator TGLiteHashList.Initialize(var hl: TGLiteHashList);
begin
  hl.FCount := 0;
end;

class operator TGLiteHashList.Copy(constref aSrc: TGLiteHashList; var aDst: TGLiteHashList);
begin
  if @aSrc = @aDst then exit;
  aDst.FNodeList := System.Copy(aSrc.FNodeList);
  aDst.FChainList := System.Copy(aSrc.FChainList);
  aDst.FCount := aSrc.FCount;
end;

class operator TGLiteHashList.AddRef(var hl: TGLiteHashList);
begin
  if hl.FNodeList <> nil then
    begin
      hl.FNodeList := System.Copy(hl.FNodeList);
      hl.FChainList := System.Copy(hl.FChainList);
    end;
end;

function TGLiteHashList.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(@Self);
end;

function TGLiteHashList.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := TReverseEnumerator.Create(@Self);
end;

function TGLiteHashList.ToArray: TArray;
var
  I: SizeInt;
begin
  System.SetLength(Result, Count);
  for I := 0 to Pred(Count) do
    Result[I] := FNodeList[I].Data;
end;

function TGLiteHashList.Reverse: TReverse;
begin
  Result := TReverse.Create(@Self);
end;

procedure TGLiteHashList.Clear;
begin
  FNodeList := nil;
  FChainList := nil;
  FCount := 0;
end;

function TGLiteHashList.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteHashList.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteHashList.EnsureCapacity(aValue: SizeInt);
begin
  if aValue <= Capacity then
    exit;
  if aValue < MAX_CONTAINER_SIZE div SizeOf(TNode) then
    begin
      if aValue <= DEFAULT_CONTAINER_CAPACITY then
        Resize(DEFAULT_CONTAINER_CAPACITY)
      else
        Resize(LGUtils.RoundUpTwoPower(aValue));
    end
  else
    CapacityExceedError(aValue);
end;

procedure TGLiteHashList.TrimToFit;
var
  NewCapacity: SizeInt;
begin
  if NonEmpty then
    begin
      NewCapacity := LGUtils.RoundUpTwoPower(Count);
      if NewCapacity < Capacity then
        Resize(NewCapacity);
    end
  else
    Clear;
end;

function TGLiteHashList.Contains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) >= 0;
end;

function TGLiteHashList.NonContains(const aValue: T): Boolean;
begin
  Result := IndexOf(aValue) < 0;
end;

function TGLiteHashList.IndexOf(const aValue: T): SizeInt;
begin
  if NonEmpty then
    Result := Find(aValue)
  else
    Result := NULL_INDEX;
end;

function TGLiteHashList.CountOf(const aValue: T): SizeInt;
begin
  if NonEmpty then
    Result := GetCountOf(aValue)
  else
    Result := 0;
end;

function TGLiteHashList.Add(const aValue: T): SizeInt;
begin
  if Count = Capacity then
    Expand;
  Result := DoAdd(aValue);
end;

function TGLiteHashList.AddAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := System.Length(a);
  EnsureCapacity(Count + Result);
  for I := 0 to System.High(a) do
    DoAdd(a[I]);
end;

function TGLiteHashList.AddAll(e: IEnumerable): SizeInt;
var
  v: T;
begin
  Result := Count;
  for v in e do
    Add(v);
  Result := Count - Result;
end;

function TGLiteHashList.AddUniq(const aValue: T): Boolean;
var
  Dummy: SizeInt;
begin
  Result := not FindOrAdd(aValue, Dummy);
end;

function TGLiteHashList.AddAllUniq(const a: array of T): SizeInt;
var
  I, Dummy: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    FindOrAdd(a[I], Dummy);
  Result := Count - Result;
end;

function TGLiteHashList.AddAllUniq(e: IEnumerable): SizeInt;
var
  v: T;
begin
  Result := Count;
  for v in e do
    AddUniq(v);
  Result := Count - Result;
end;

function TGLiteHashList.AddOrUpdate(const aValue: T; out aIndex: SizeInt): Boolean;
begin
  if FindOrAdd(aValue, aIndex) then
    begin
      FNodeList[aIndex].Data := aValue;
      Result := False;
    end
  else
    Result := True;
end;

function TGLiteHashList.AddOrUpdate(const aValue: T): Boolean;
var
  I: SizeInt;
begin
  if FindOrAdd(aValue, I) then
    begin
      FNodeList[I].Data := aValue;
      Result := False;
    end
  else
    Result := True;
end;

function TGLiteHashList.AddAllOrUpdate(const a: array of T): SizeInt;
var
  I, J: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    if FindOrAdd(a[I], J) then
      FNodeList[J].Data := a[I];
  Result := Count - Result;
end;

function TGLiteHashList.AddAllOrUpdate(e: IEnumerable): SizeInt;
var
  I: SizeInt;
  v: T;
begin
  Result := Count;
  for v in e do
    if FindOrAdd(v, I) then
      FNodeList[I].Data := v;
  Result := Count - Result;
end;

procedure TGLiteHashList.Insert(aIndex: SizeInt; const aValue: T);
begin
  if SizeUInt(aIndex) <= SizeUInt(Count) then
    begin
      if Count = Capacity then
        Expand;
      DoInsert(aIndex, aValue);
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteHashList.Delete(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DoDelete(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteHashList.Remove(const aValue: T): Boolean;
begin
  if NonEmpty then
    Result := DoRemove(aValue)
  else
    Result := False;
end;

{ TGLiteHashList2 }

class procedure TGLiteHashList2.CapacityExceedError(aValue: SizeInt);
begin
  raise ELGCapacityExceed.CreateFmt(SECapacityExceedFmt, [aValue]);
end;

function TGLiteHashList2.GetCapacity: SizeInt;
begin
  Result := System.Length(FNodeList);
end;

function TGLiteHashList2.GetItem(aIndex: SizeInt): TEntry;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FNodeList[aIndex].Data
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteHashList2.GetKey(aIndex: SizeInt): TKey;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FNodeList[aIndex].Data.Key
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteHashList2.GetMutable(aIndex: SizeInt): PEntry;
begin
  Result := @FNodeList[aIndex].Data;
end;

procedure TGLiteHashList2.SetItem(aIndex: SizeInt; const e: TEntry);
var
  I: SizeInt;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    begin
      if TKeyEqRel.Equal(e.Key, FNodeList[aIndex].Data.Key) then
        begin
          FNodeList[aIndex].Data := e;
          exit;
        end;
      RemoveFromChain(aIndex);
      //add to new chain
      FNodeList[aIndex].Data := e;
      FNodeList[aIndex].Hash := TKeyEqRel.HashCode(e.Key);
      I := FNodeList[aIndex].Hash and Pred(Capacity);
      FNodeList[aIndex].Next := FChainList[I];
      FChainList[I] := aIndex;
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteHashList2.InitialAlloc;
begin
  System.SetLength(FNodeList, DEFAULT_CONTAINER_CAPACITY);
  System.SetLength(FChainList, DEFAULT_CONTAINER_CAPACITY);
  System.FillChar(Pointer(FChainList)^, System.Length(FChainList) * SizeOf(SizeInt), $ff);
end;

procedure TGLiteHashList2.Rehash;
var
  I, J, Mask: SizeInt;
begin
  Mask := Pred(Capacity);
  System.FillChar(Pointer(FChainList)^, Succ(Mask) * SizeOf(SizeInt), $ff);
  for I := 0 to Pred(Count) do
    begin
      J := FNodeList[I].Hash and Mask;
      FNodeList[I].Next := FChainList[J];
      FChainList[J] := I;
    end;
end;

procedure TGLiteHashList2.Resize(aNewCapacity: SizeInt);
begin
  System.SetLength(FNodeList, aNewCapacity);
  System.SetLength(FChainList, aNewCapacity);
  Rehash;
end;

procedure TGLiteHashList2.Expand;
begin
  if Capacity > 0 then
    begin
      if Capacity < MAX_CONTAINER_SIZE div SizeOf(TNode) then
        Resize(Capacity shl 1)
      else
        CapacityExceedError(Capacity shl 1);
    end
  else
    InitialAlloc;
end;

function TGLiteHashList2.FindEntry(const aKey: TKey; aHash: SizeInt): PEntry;
var
  I: SizeInt;
begin
  I := FChainList[aHash and Pred(Capacity)];
  while I <> NULL_INDEX do
    begin
      if (FNodeList[I].Hash = aHash) and TKeyEqRel.Equal(FNodeList[I].Data.Key, aKey) then
        exit(@FNodeList[I].Data);
      I := FNodeList[I].Next;
    end;
  Result := nil;
end;

function TGLiteHashList2.DoFind(const aKey: TKey; aHash: SizeInt): SizeInt;
begin
  Result := FChainList[aHash and Pred(Capacity)];
  while Result <> NULL_INDEX do
    begin
      if (FNodeList[Result].Hash = aHash) and TKeyEqRel.Equal(FNodeList[Result].Data.Key, aKey) then
        exit;
      Result := FNodeList[Result].Next;
    end;
end;

function TGLiteHashList2.DoFind(const aKey: TKey): SizeInt;
begin
  Result := DoFind(aKey, TKeyEqRel.HashCode(aKey));
end;

function TGLiteHashList2.DoFindUniq(const aKey: TKey): PEntry;
var
  I, h: SizeInt;
begin
  h := TKeyEqRel.HashCode(aKey);
  I := FChainList[h and Pred(Capacity)];
  Result := nil;
  while I <> NULL_INDEX do
    begin
      if (FNodeList[I].Hash = h) and TKeyEqRel.Equal(FNodeList[I].Data.Key, aKey) then
        begin
          if Result <> nil then exit(nil);
          Result := @FNodeList[I].Data;
        end;
      I := FNodeList[I].Next;
    end;
end;

function TGLiteHashList2.TestHasUniq(aIndex: SizeInt): Boolean;
var
  I, h, cnt: SizeInt;
  k: TKey;
begin
  h := FNodeList[aIndex].Hash;
  k := FNodeList[aIndex].Data.Key;
  I := FChainList[h and Pred(Capacity)];
  cnt := 0;
  while I <> NULL_INDEX do
    begin
      if (I = aIndex)or((FNodeList[I].Hash = h) and TKeyEqRel.Equal(FNodeList[I].Data.Key, k)) then
        begin
          if cnt = 1 then exit(False);
          Inc(cnt);
        end;
      I := FNodeList[I].Next;
    end;
  Result := True;
end;

function TGLiteHashList2.GetCountOf(const aKey: TKey): SizeInt;
var
  h, I: SizeInt;
begin
  h := TKeyEqRel.HashCode(aKey);
  I := FChainList[h and Pred(Capacity)];
  Result := 0;
  while I <> NULL_INDEX do
    begin
      if (FNodeList[I].Hash = h) and TKeyEqRel.Equal(FNodeList[I].Data.Key, aKey) then
        Inc(Result);
      I := FNodeList[I].Next;
    end;
end;

function TGLiteHashList2.DoAdd(const e: TEntry): SizeInt;
begin
  Result := Count;
  FNodeList[Result].Hash := TKeyEqRel.HashCode(e.Key);
  FNodeList[Result].Data := e;
  FNodeList[Result].Next := FChainList[FNodeList[Result].Hash and Pred(Capacity)];
  FChainList[FNodeList[Result].Hash and Pred(Capacity)] := Result;
  Inc(FCount);
end;

function TGLiteHashList2.DoAddHash(aHash: SizeInt): SizeInt;
begin
  Result := Count;
  FNodeList[Result].Hash := aHash;
  FNodeList[Result].Next := FChainList[aHash and Pred(Capacity)];
  FChainList[aHash and Pred(Capacity)] := Result;
  Inc(FCount);
end;

procedure TGLiteHashList2.DoInsert(aIndex: SizeInt; const e: TEntry);
begin
  if aIndex < Count then
    begin
      System.Move(FNodeList[aIndex], FNodeList[Succ(aIndex)], (Count - aIndex) * SizeOf(TNode));
      if IsManagedType(TEntry) then
        System.FillChar(FNodeList[aIndex].Data, SizeOf(TEntry), 0);
      FNodeList[aIndex].Hash := TKeyEqRel.HashCode(e.Key);
      FNodeList[aIndex].Data := e;
      Inc(FCount);
      Rehash;
    end
  else
    DoAdd(e);
end;

procedure TGLiteHashList2.DoDelete(aIndex: SizeInt; out e: TEntry);
begin
  Dec(FCount);
  e := FNodeList[aIndex].Data;
  if IsManagedType(TEntry) then
    FNodeList[aIndex].Data := Default(TEntry);
  if aIndex < Count then
    begin
      System.Move(FNodeList[Succ(aIndex)], FNodeList[aIndex], (Count - aIndex) * SizeOf(TNode));
      if IsManagedType(TEntry) then
        System.FillChar(FNodeList[Count].Data, SizeOf(TEntry), 0);
      Rehash;
    end
  else   // last element
    RemoveFromChain(aIndex);
end;

procedure TGLiteHashList2.RemoveFromChain(aIndex: SizeInt);
var
  I, Curr, Prev: SizeInt;
begin
  I := FNodeList[aIndex].Hash and Pred(Capacity);
  Curr := FChainList[I];
  Prev := NULL_INDEX;
  while Curr <> NULL_INDEX do
    begin
      if Curr = aIndex then
        begin
          if Prev <> NULL_INDEX then
            FNodeList[Prev].Next := FNodeList[Curr].Next
          else
            FChainList[I] := FNodeList[Curr].Next;
          exit;
        end;
      Prev := Curr;
      Curr := FNodeList[Curr].Next;
    end;
end;

function TGLiteHashList2.DoRemove(const aKey: TKey; out e: TEntry): Boolean;
var
  ToRemove: SizeInt;
begin
  ToRemove := DoFind(aKey);
  if ToRemove >= 0 then
    begin
      DoDelete(ToRemove, e);
      exit(True);
    end;
  Result := False;
end;

function TGLiteHashList2.DoFindOrAdd(const aKey: TKey; out p: PEntry; out aIndex: SizeInt): Boolean;
var
  h: SizeInt;
begin
  h := TKeyEqRel.HashCode(aKey);
  aIndex := NULL_INDEX;
  if Count > 0 then
    aIndex := DoFind(aKey, h);
  Result := aIndex <> NULL_INDEX;
  if not Result then
    begin
      if Count = Capacity then
        Expand;
      aIndex := DoAddHash(h);
    end;
  p := @FNodeList[aIndex].Data;
end;

class operator TGLiteHashList2.Initialize(var hl: TGLiteHashList2);
begin
  hl.FCount := 0;
end;

class operator TGLiteHashList2.Copy(constref aSrc: TGLiteHashList2; var aDst: TGLiteHashList2);
begin
  aDst.FNodeList := System.Copy(aSrc.FNodeList);
  aDst.FChainList := System.Copy(aSrc.FChainList);
  aDst.FCount := aSrc.FCount;
end;

class operator TGLiteHashList2.AddRef(var hl: TGLiteHashList2);
begin
  if hl.FNodeList <> nil then
    begin
      hl.FNodeList := System.Copy(hl.FNodeList);
      hl.FChainList := System.Copy(hl.FChainList);
    end;
end;

{ TGLiteHashList2.TEnumerator }

function TGLiteHashList2.TEnumerator.GetCurrent: TEntry;
begin
  Result := FCurrNode^.Data;
end;

procedure TGLiteHashList2.TEnumerator.Init(aList: PLiteHashList);
begin
  if aList^.Count > 0 then
    begin
      FCurrNode := PNode(aList^.FNodeList) - 1;
      FLastNode := FCurrNode + aList^.Count;
    end
  else
    begin
      FCurrNode := nil;
      FLastNode := nil;
    end;
end;

function TGLiteHashList2.TEnumerator.MoveNext: Boolean;
begin
  if FCurrNode < FLastNode then
    begin
      Inc(FCurrNode);
      exit(True);
    end;
  Result := False;
end;

{ TGLiteHashList2.TReverseEnumerator }

function TGLiteHashList2.TReverseEnumerator.GetCurrent: TEntry;
begin
  Result := FCurrNode^.Data;
end;

procedure TGLiteHashList2.TReverseEnumerator.Init(aList: PLiteHashList);
begin
  if aList^.Count > 0 then
    begin
      FFirstNode := PNode(aList^.FNodeList);
      FCurrNode := FFirstNode + aList^.Count;
    end
  else
    begin
      FFirstNode := nil;
      FCurrNode := nil;
    end;
end;

function TGLiteHashList2.TReverseEnumerator.MoveNext: Boolean;
begin
  if FCurrNode > FFirstNode then
    begin
      Dec(FCurrNode);
      exit(True);
    end;
  Result := False;
end;

{ TGLiteHashList2.TReverse }

procedure TGLiteHashList2.TReverse.Init(aList: PLiteHashList);
begin
  FList := aList;
end;

function TGLiteHashList2.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result.Init(FList);
end;

{ TGLiteHashList2.TEqualEnumerator }

function TGLiteHashList2.TEqualEnumerator.GetCurrent: TEntry;
begin
  Result := FList^.FNodeList[FCurrIdx].Data;
end;

procedure TGLiteHashList2.TEqualEnumerator.Init(const aKey: TKey; aList: PLiteHashList);
begin
  FKey := aKey;
  FList := aList;
  FCurrIdx := NULL_INDEX;
  FHash := TKeyEqRel.HashCode(aKey);
  FInLoop := False;
end;

function TGLiteHashList2.TEqualEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FList^.Count = 0 then exit(False);
  if FInLoop then
    begin
      if FCurrIdx = NULL_INDEX then exit(False);
      with FList^ do
        begin
          I := FNodeList[FCurrIdx].Next;
          while I <> NULL_INDEX do
            begin
              if(FNodeList[I].Hash = FHash)and TKeyEqRel.Equal(FNodeList[I].Data.Key, FKey) then
                break;
              I := FNodeList[I].Next;
            end;
        end;
      FCurrIdx := I;
    end
  else
    begin
      FCurrIdx := FList^.DoFind(FKey, FHash);
      FInLoop := True;
    end;
  Result := FCurrIdx <> NULL_INDEX;
end;

procedure TGLiteHashList2.TEqualEnumerator.Reset;
begin
  FCurrIdx := NULL_INDEX;
  FInLoop := False;
end;

{ TGLiteHashList2.TEqualKeys }

procedure TGLiteHashList2.TEqualKeys.Init(const aKey: TKey; aList: PLiteHashList);
begin
  FKey := aKey;
  FList := aList;
end;

function TGLiteHashList2.TEqualKeys.GetEnumerator: TEqualEnumerator;
begin
  Result.Init(FKey, FList);
end;

function TGLiteHashList2.GetEnumerator: TEnumerator;
begin
  Result.Init(@Self);
end;

function TGLiteHashList2.GetReverseEnumerator: TReverseEnumerator;
begin
  Result.Init(@Self);
end;

function TGLiteHashList2.GetEqualEnumerator(const aKey: TKey): TEqualEnumerator;
begin
  Result{%H-}.Init(aKey, @Self);
end;

function TGLiteHashList2.ToArray: TEntryArray;
var
  I: SizeInt;
begin
  System.SetLength(Result, Count);
  for I := 0 to Pred(Count) do
    Result[I] := FNodeList[I].Data;
end;

function TGLiteHashList2.Reverse: TReverse;
begin
  Result{%H-}.Init(@Self);
end;

function TGLiteHashList2.EqualKeys(const aKey: TKey): TEqualKeys;
begin
  Result{%H-}.Init(aKey, @Self);
end;

procedure TGLiteHashList2.Clear;
begin
  FNodeList := nil;
  FChainList := nil;
  FCount := 0;
end;

procedure TGLiteHashList2.MakeEmpty;
var
  I: SizeInt;
begin
  if Count = 0 then exit;
  System.FillChar(FChainList[0], System.Length(FChainList) * SizeOf(SizeInt), $ff);
  for I := 0 to Pred(Count) do
    FNodeList[I] := Default(TNode);
  FCount := 0;
end;

function TGLiteHashList2.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteHashList2.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteHashList2.EnsureCapacity(aValue: SizeInt);
begin
  if aValue > Capacity then
    begin
      if aValue < MAX_CONTAINER_SIZE div SizeOf(TNode) then
        aValue := LGUtils.RoundUpTwoPower(aValue)
      else
        CapacityExceedError(aValue);
      Resize(aValue);
    end;
end;

procedure TGLiteHashList2.TrimToFit;
var
  NewCapacity: SizeInt;
begin
  if NonEmpty then
    begin
      NewCapacity := LGUtils.RoundUpTwoPower(Count);
      if NewCapacity < Capacity then
        Resize(NewCapacity);
    end
  else
    Clear;
end;

function TGLiteHashList2.Contains(const aKey: TKey): Boolean;
begin
  Result := IndexOf(aKey) >= 0;
end;

function TGLiteHashList2.ContainsUniq(const aKey: TKey): Boolean;
begin
  if NonEmpty then
    exit(DoFindUniq(aKey) <> nil);
  Result := False;
end;

function TGLiteHashList2.NonContains(const aKey: TKey): Boolean;
begin
  Result := IndexOf(aKey) < 0;
end;

function TGLiteHashList2.Find(const aKey: TKey): PEntry;
begin
  if NonEmpty then
    exit(FindEntry(aKey, TKeyEqRel.HashCode(aKey)));
  Result := nil;
end;

function TGLiteHashList2.FindOrAdd(const aKey: TKey; out p: PEntry): Boolean;
var
  Dummy: SizeInt;
begin
  Result := DoFindOrAdd(aKey, p, Dummy);
end;

function TGLiteHashList2.FindUniq(const aKey: TKey): PEntry;
begin
  if NonEmpty then
    exit(DoFindUniq(aKey));
  Result := nil;
end;

function TGLiteHashList2.IndexOf(const aKey: TKey): SizeInt;
begin
  if NonEmpty then
    Result := DoFind(aKey)
  else
    Result := NULL_INDEX;
end;

function TGLiteHashList2.CountOf(const aKey: TKey): SizeInt;
begin
  if NonEmpty then
    Result := GetCountOf(aKey)
  else
    Result := 0;
end;

function TGLiteHashList2.Add(const e: TEntry): SizeInt;
begin
  if Count = Capacity then
    Expand;
  Result := DoAdd(e);
end;

function TGLiteHashList2.AddAll(const a: array of TEntry): SizeInt;
var
  I: SizeInt;
begin
  Result := System.Length(a);
  EnsureCapacity(Count + Result);
  for I := 0 to System.High(a) do
    DoAdd(a[I]);
end;

function TGLiteHashList2.AddAll(e: IEntryEnumerable): SizeInt;
var
  Entry: TEntry;
begin
  Result := Count;
  for Entry in e do
    Add(Entry);
  Result := Count - Result;
end;

function TGLiteHashList2.AddUniq(const e: TEntry): Boolean;
var
  Dummy: SizeInt;
  p: PEntry;
begin
  Result := not DoFindOrAdd(e.Key, p, Dummy);
  if Result then
    p^ := e;
end;

function TGLiteHashList2.AddUniq(const e: TEntry; out p: PEntry): Boolean;
var
  Dummy: SizeInt;
begin
  Result := not DoFindOrAdd(e.Key, p, Dummy);
  if Result then
    p^ := e;
end;

function TGLiteHashList2.AddAllUniq(const a: array of TEntry): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    AddUniq(a[I]);
  Result := Count - Result;
end;

function TGLiteHashList2.AddAllUniq(e: IEntryEnumerable): SizeInt;
var
  Entry: TEntry;
begin
  Result := Count;
  for Entry in e do
    AddUniq(Entry);
  Result := Count - Result;
end;

function TGLiteHashList2.AddOrUpdate(const e: TEntry; out aIndex: SizeInt): Boolean;
var
  p: PEntry;
begin
  Result := not DoFindOrAdd(e.Key, p, aIndex);
  p^ := e;
end;

function TGLiteHashList2.AddOrUpdate(const e: TEntry): Boolean;
var
  Dummy: SizeInt;
  p: PEntry;
begin
  Result := not DoFindOrAdd(e.Key, p, Dummy);
  p^ := e;
end;

function TGLiteHashList2.AddAllOrUpdate(const a: array of TEntry): SizeInt;
var
  I, Dummy: SizeInt;
  p: PEntry;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    begin
      DoFindOrAdd(a[I].Key, p, Dummy);
      p^ := a[I];
    end;
  Result := Count - Result;
end;

function TGLiteHashList2.AddAllOrUpdate(e: IEntryEnumerable): SizeInt;
var
  Entry: TEntry;
begin
  Result := Count;
  for Entry in e do
    AddOrUpdate(Entry);
  Result := Count - Result;
end;

function TGLiteHashList2.HasUniqKey(aIndex: SizeInt): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    exit(TestHasUniq(aIndex));
  Result := False;
end;

procedure TGLiteHashList2.Insert(aIndex: SizeInt; const e: TEntry);
begin
  if SizeUInt(aIndex) <= SizeUInt(Count) then
    begin
      if Count = Capacity then
        Expand;
      DoInsert(aIndex, e);
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteHashList2.TryInsert(aIndex: SizeInt; const e: TEntry): Boolean;
begin
  if SizeUInt(aIndex) <= SizeUInt(Count) then
    begin
      if Count = Capacity then
        Expand;
      DoInsert(aIndex, e);
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteHashList2.Delete(aIndex: SizeInt; out e: TEntry);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    DoDelete(aIndex, e)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteHashList2.TryDelete(aIndex: SizeInt; out e: TEntry): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    begin
      DoDelete(aIndex, e);
      exit(True);
    end;
  Result := False;
end;

function TGLiteHashList2.Remove(const aKey: TKey; out e: TEntry): Boolean;
begin
  if NonEmpty then
    Result := DoRemove(aKey, e)
  else
    Result := False;
end;

end.

