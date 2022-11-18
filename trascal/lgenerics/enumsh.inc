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

  //IGEnumerable special descendents

  generic TGAutoEnumerable<T> = class abstract(specialize TGEnumerator<T>, specialize IGEnumerable<T>)
  protected
  type
    TEnumerable = class(specialize TGEnumerable<T>, specialize IGEnumerable<T>, IObjInstance)
    protected
      FOwner: TGAutoEnumerable;
    public
      constructor Create(e: TGAutoEnumerable);
      function GetEnumerator: TSpecEnumerator; override;
    end;

  public
  type
    IEnumerable     = TEnumerable.IEnumerable;
    TSpecEnumerator = TEnumerable.TSpecEnumerator;

  protected
  var
    FEnumerable: TEnumerable;
    property Enumerable: TEnumerable read FEnumerable implements IEnumerable;
  public
    constructor Create;
    destructor  Destroy; override;
  end;

  generic TGEnumCursor<T> = class(specialize TGAutoEnumerable<T>)
  protected
    FEnum: TSpecEnumerator;
    function  GetCurrent: T; override;
  public
    constructor Create(e: TSpecEnumerator);
    destructor  Destroy; override;
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGEnumRegularFilter<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TTest = TEnumerable.TTest;

  private
    FTest: TTest;
  public
    constructor Create(e: TSpecEnumerator; aTest: TTest);
    function MoveNext: Boolean; override;
  end;

  generic TGEnumDelegatedFilter<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TOnTest = TEnumerable.TOnTest;

  private
    FTest: TOnTest;
  public
    constructor Create(e: TSpecEnumerator; aTest: TOnTest);
    function MoveNext: Boolean; override;
  end;

  generic TGEnumNestedFilter<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TNestTest = TEnumerable.TNestTest;

  private
    FTest: TNestTest;
  public
    constructor Create(e: TSpecEnumerator; aTest: TNestTest);
    function MoveNext: Boolean; override;
  end;

  generic TGEnumRegularMap<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TMapFunc = TEnumerable.TMapFunc;

  private
    FMap: TMapFunc;
  public
    constructor Create(e: TSpecEnumerator; aMap: TMapFunc);
    function GetCurrent: T; override;
  end;

  generic TGEnumDelegatedMap<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TOnMap = TEnumerable.TOnMap;

  private
    FMap: TOnMap;
  public
    constructor Create(e: TSpecEnumerator; aMap: TOnMap);
    function GetCurrent: T; override;
  end;

  generic TGEnumNestedMap<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TNestMap = TEnumerable.TNestMap;

  private
    FMap: TNestMap;
  public
    constructor Create(e: TSpecEnumerator; aMap: TNestMap);
    function GetCurrent: T; override;
  end;

  generic TGSkipEnumerable<T> = class(specialize TGEnumCursor<T>)
  private
    FSkipCount,
    FSkipped: SizeInt;
    procedure Skip; inline;
  public
    constructor Create(e: TSpecEnumerator; aCount: SizeInt);
    procedure Reset; override;
  end;

  generic TGRegularSkipWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TTest = TEnumerable.TTest;

  private
    FTest: TTest;
    FSkipDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGDelegatedSkipWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TOnTest = TEnumerable.TOnTest;

  private
    FTest: TOnTest;
    FSkipDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TOnTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGNestedSkipWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TNestTest = TEnumerable.TNestTest;
  private
    FTest: TNestTest;
    FSkipDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TNestTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGLimitEnumerable<T> = class(specialize TGEnumCursor<T>)
  private
    FLimit,
    FCurrent: SizeInt;
  public
    constructor Create(e: TSpecEnumerator; aCount: SizeInt);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGRegularTakeWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TTest = TEnumerable.TTest;

  private
    FTest: TTest;
    FDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGDelegatedTakeWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TOnTest = TEnumerable.TOnTest;

  private
    FTest: TOnTest;
    FDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TOnTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGNestedTakeWhileEnumerable<T> = class(specialize TGEnumCursor<T>)
  public
  type
    TNestTest = TEnumerable.TNestTest;

  private
    FTest: TNestTest;
    FDone: Boolean;
  public
    constructor Create(e: TSpecEnumerator; aTest: TNestTest);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGArrayCursor<T> = class(specialize TGAutoEnumerable<T>)
  public
  type
    TArray = TEnumerable.TArray;

  protected
  type
    TArrayEnumerable = class(TEnumerable)
      function ToArray: TArray; override;
    end;

  var
    FArray: TArray;
    FCurrIndex: SizeInt;
    function  GetCurrent: T; override;
  public
    constructor Create(const a: TArray);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGArrayReverse<T> = class(specialize TGAutoEnumerable<T>)
  public
  type
    TArray = TEnumerable.TArray;

  protected
  type
    TArrayEnumerable = class(TEnumerable)
      function ToArray: TArray; override;
    end;

  var
    FArray: TArray;
    FPosition: SizeInt;
    function  GetCurrent: T; override;
  public
    constructor Create(const a: TArray);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  generic TGArrayEnumerator<T> = class(specialize TGEnumerator<T>)
  public
  type
    TArray = specialize TGArray<T>;

  protected
    FArray: TArray;
    FPosition,
    FLast: SizeInt;
    function  GetCurrent: T; override;
  public
    constructor Create(const a: TArray);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;
