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

  //TGCustomContainer special descendents

  generic TGCustomArrayBuffer<T> = class abstract(specialize TGAbstractContainer<T>)
  protected
  type
    TCopyHelper = class(specialize TGArrayHelpUtil<T>); // need access to protected functions

  var
    FItems: TArray;
    FCount: SizeInt;
    function  GetCount: SizeInt; override;
    function  GetCapacity: SizeInt; override;
    procedure CheckEmpty; inline;
    procedure DoClear; override;
    function  IndexInRange(aIndex: SizeInt): Boolean; inline;
    function  IndexInInsertRange(aIndex: SizeInt): Boolean; inline;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    procedure CheckInsertIndexRange(aIndex: SizeInt); inline;
    property  ElemCount: SizeInt read FCount;
  public
    destructor Destroy; override;
  end;

  generic TGCustomArrayContainer<T> = class abstract(specialize TGCustomArrayBuffer<T>)
  public
  type
    TEnumerator = class(TContainerEnumerator)
    private
      FItems: TArray;
      FCurrIndex,
      FLast: SizeInt;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(c: TGCustomArrayContainer);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnumerator = class(TContainerEnumerable)
    protected
      FItems: TArray;
      FCurrIndex,
      FCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(c: TGCustomArrayContainer);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;
  protected
    procedure Expand(aValue: SizeInt);
    procedure ItemAdding; inline;
    function  Append(const aValue: T): SizeInt; inline;
    function  AppendArray(const a: array of T): SizeInt;
    function  AppendEnum(e: IEnumerable): SizeInt;
    function  AppendContainer(aContainer: TSpecContainer): SizeInt;
    function  AppendEnumerable(e: IEnumerable): SizeInt;
    function  GetReverse: IEnumerable;
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    procedure CopyItems(aBuffer: PItem); override;
  public
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
  { consumes an array a; after the constructor finishes, the value of a is nil }
    constructor From(var a: TArray);
    function  Reverse: IEnumerable; override;
    function  ToArray: TArray; override;
  end;

  { TGLiteDynBuffer: for internal use ONLY }
  generic TGLiteDynBuffer<T> = record
  type
    PGLiteDynBuffer = ^TGLiteDynBuffer;
    TArray = array of T;
    TItem  = T;
    PItem  = ^T;

    TEnumerator = record
    private
      FCurrent,
      FLast: PItem;
      FItems: TArray;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TMutableEnumerator = record
    private
      FCurrent,
      FLast: PItem;
      FItems: TArray;
    public
      function  MoveNext: Boolean; inline;
      property  Current: PItem read FCurrent;
    end;

    TMutables = record
    private
      FBuffer: PGLiteDynBuffer;
    public
      function GetEnumerator: TMutableEnumerator; inline;
    end;

    TReverseEnumerator = record
    private
      FCurrent,
      FFirst: PItem;
      FItems: TArray;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;


    TReverse = record
    private
      FBuffer: PGLiteDynBuffer;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  private
    function  GetCapacity: SizeInt; inline;
    procedure Expand(aValue: SizeInt);
    class operator Initialize(var b: TGLiteDynBuffer); inline;
    class operator Copy(constref aSrc: TGLiteDynBuffer; var aDst: TGLiteDynBuffer); inline;
    class operator AddRef(var b: TGLiteDynBuffer); inline;
  public
    FItems: TArray;
    FCount: SizeInt;
    procedure CheckEmpty; inline;
    procedure ItemAdding; inline;
    procedure FinalizeItems(aFrom, aCount: SizeInt);
    procedure Clear;
    procedure MakeEmpty; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    function  GetEnumerator: TEnumerator;
    function  GetMutableEnumerator: TMutableEnumerator;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    function  PushLast(const aValue: T): SizeInt; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TGCustomRingArrayBuffer }

  generic TGCustomRingArrayBuffer<T> = class abstract(specialize TGCustomArrayBuffer<T>)
  public
  type

    TEnumerator = class(TContainerEnumerator)
    private
      FItems: TArray;
      FCurrIndex,
      FHead,
      FCount,
      FRest,
      FCapacity: SizeInt;
    protected
      function  GetCurrent: T; override;
    public
      constructor Create(c: TGCustomRingArrayBuffer);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnum = class(TContainerEnumerable)
    protected
      FItems: TArray;
      FCurrIndex,
      FHead,
      FCount,
      FRest: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(c: TGCustomRingArrayBuffer);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  protected
    FHead: SizeInt;
    procedure Expand(aValue: SizeInt);
    procedure Grow(aValue: SizeInt);
    procedure Shrink;
    procedure ItemAdding; inline;
    procedure Append(const aValue: T);
    function  AppendArray(const a: array of T): SizeInt;
    function  AppendContainer(aContainer: TSpecContainer): SizeInt;
    function  AppendEnum(e: IEnumerable): SizeInt;
    function  AppendEnumerable(e: IEnumerable): SizeInt;
    function  ExtractHead: T;
  { iterates items from head to tail }
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoClear; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    procedure CopyItems(aBuffer: PItem); override;
    property  Head: SizeInt read FHead;
  public
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const A: array of T);
    constructor Create(e: IEnumerable);
    function  Reverse: IEnumerable; override;
  end;

  { TGLiteRingDynBuffer: for internal use ONLY }
  generic TGLiteRingDynBuffer<T> = record
  type
    PGLiteRingDynBuffer = ^TGLiteRingDynBuffer;
    TArray = array of T;
    TItem  = T;
    PItem  = ^T;

    TEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FHead,
      FCount,
      FRest,
      FCapacity: SizeInt;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;

    TMutableEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FHead,
      FCount,
      FRest,
      FCapacity: SizeInt;
      function  GetCurrent: PItem; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: PItem read GetCurrent;
    end;

    TMutables = record
    private
      FBuffer: PGLiteRingDynBuffer;
    public
      function GetEnumerator: TMutableEnumerator; inline;
    end;

    TReverseEnumerator = record
    private
      FItems: TArray;
      FCurrIndex,
      FHead,
      FCount,
      FRest,
      FCapacity: SizeInt;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: T read GetCurrent;
    end;


    TReverse = record
    private
      FBuffer: PGLiteRingDynBuffer;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  var
    FItems: TArray;
  private
    FCount,
    FHead: SizeInt;
    function  GetCapacity: SizeInt; inline;
    procedure Expand(aValue: SizeInt);
    procedure Grow(aValue: SizeInt);
    procedure Shrink;
    procedure CapacityExceedError(aValue: SizeInt);
    procedure CheckEmpty; inline;
    class operator Initialize(var b: TGLiteRingDynBuffer); inline;
    class operator Copy(constref aSrc: TGLiteRingDynBuffer; var aDst: TGLiteRingDynBuffer); inline;
    class operator AddRef(var b: TGLiteRingDynBuffer); inline;
  public
    // does not checks bounds !!!
    function  InternalIndex(aIndex: SizeInt): SizeInt; inline;
    // does not checks count !!!
    function  TailIndex: SizeInt; inline;
    procedure ItemAdding; inline;
    // does not checks count !!!
    function  PopHead: T;
    // does not checks count !!!
    function  PopTail: T;
    procedure Clear; inline;
    procedure MakeEmpty;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  GetMutableEnumerator: TMutableEnumerator;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray;
    procedure PushLast(const aValue: T);
    procedure PushFirst(const aValue: T);
    function  PopFirst: T;
    function  TryPopFirst(out aValue: T): Boolean;
    function  PopLast: T;
    function  TryPopLast(out aValue: T): Boolean;
    function  PeekFirst: T; inline;
    function  PeekFirstItem: PItem; inline;
    function  TryPeekFirst(out aValue: T): Boolean;
    function  TryPeekFirstItem(out aValue: PItem): Boolean;
    function  PeekLast: T; inline;
    function  TryPeekLast(out aValue: T): Boolean;
    function  PeekLastItem: PItem; inline;
    function  TryPeekLastItem(out aValue: PItem): Boolean;
    property  Head: SizeInt read FHead;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;




