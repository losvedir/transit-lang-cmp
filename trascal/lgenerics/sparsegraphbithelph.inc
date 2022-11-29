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

type
  TSquareBitMatrix = record
  private
  type
    TBits = array of SizeUInt;
  var
    FBits: TBits;
    FSize: SizeUInt;
    function  GetBit(I, J: SizeInt): Boolean; inline;
    function  GetSize: SizeInt; inline;
    procedure SetBit(I, J: SizeInt; aValue: Boolean); inline;
    class operator Initialize(var aMatrix: TSquareBitMatrix);
  public
    class function MaxSize: SizeInt; static; inline;
    constructor Create(aSize: SizeInt);
    constructor CreateAndSet(aSize: SizeInt);
    procedure ClearBits; inline;
    procedure Clear; inline;
    property  Size: SizeInt read GetSize;
  { indices does not checks }
    property  Bits[I, J: SizeInt]: Boolean read GetBit write SetBit; default;
  end;

  TBits256 = record
  public
  const
    BITNESS      = 256;
    BIT_PER_LIMB = BitsizeOf(SizeUInt);
    LIMB_COUNT = BITNESS div BIT_PER_LIMB;

  type
    PBits256 = ^TBits256;

    TEnumerator = record
    private
      FValue: PBits256;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      FInCycle: Boolean;
      function GetCurrent: SizeInt; inline;
      function FindFirst: Boolean;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FValue: PBits256;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      FInCycle: Boolean;
      function GetCurrent: SizeInt; inline;
      function FindFirst: Boolean;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

    TReverse = record
    private
      FValue: PBits256;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  private
  type
    TBits = array[0..Pred(LIMB_COUNT)] of SizeUInt;

  var
    FBits: TBits;
    function  GetBit(aIndex: SizeInt): Boolean; inline;
    procedure SetBit(aIndex: SizeInt; aValue: Boolean); inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    procedure InitRange(aRange: SizeInt);
    procedure InitZero; inline;
  { returns an array containing the indices of the set bits }
    function  ToArray: TIntArray;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean; inline;
  { returns index of the least significant bit }
    function  Bsf: SizeInt;
  { returns index of the most significant bit }
    function  Bsr: SizeInt;
    function  Intersecting(const aValue: TBits256): Boolean;
  { returns the number of bits in the intersection with aValue }
    function  IntersectionPop(const aValue: TBits256): SizeInt;
    function  Contains(const aValue: TBits256): Boolean;
  { returns the number of bits that will be added when union with aValue }
    function  JoinGain(const aValue: TBits256): SizeInt;
    procedure Join(const aValue: TBits256);
    function  Union(const aValue: TBits256): TBits256; inline;
    procedure Subtract(const aValue: TBits256); inline;
    function  Difference(const aValue: TBits256): TBits256;
    procedure Intersect(const aValue: TBits256); inline;
    function  Intersection(const aValue: TBits256): TBits256;
  { returns count of set bits }
    function  PopCount: SizeInt;
    property  Bits[aIndex: SizeInt]: Boolean read GetBit write SetBit; default;
  end;

  TBitMatrix256 = array of TBits256;
  TBoolMatrix   = array of TBoolVector;

