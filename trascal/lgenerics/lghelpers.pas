{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Helpers for some basic types.                                           *
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
unit lgHelpers;

{$MODE OBJFPC}{$H+}
{$MODESWITCH TYPEHELPERS}
{$MODESWITCH ADVANCEDRECORDS}
{$INLINE ON}

interface

uses
  Classes,
  SysUtils,
  typinfo,
  variants,
  lgUtils,
  lgHash;

type

  TGGuidHelper = record helper(TGuidHelper) for TGUID
    class function HashCode(const aValue: TGUID): SizeInt; static; inline;
    class function Equal(const L, R: TGUID): Boolean; static; inline;
    class function Less(const L, R: TGUID): Boolean; static; inline;
  end;

  TStrHelper = type helper for string
    class function HashCode(const aValue: string): SizeInt; static; inline;
    class function Equal(const L, R: string): Boolean; static; inline;
    class function Less(const L, R: string): Boolean; static; inline;
  end;

  TAStrHelper = type helper(TStringHelper) for ansistring
    class function HashCode(const aValue: ansistring): SizeInt; static; inline;
    class function Equal(const L, R: ansistring): Boolean; static; inline;
    class function Less(const L, R: ansistring): Boolean; static;
  end;

  TWStrHelper = type helper for widestring
    class function HashCode(const aValue: widestring): SizeInt; static; inline;
    class function Equal(const L, R: widestring): Boolean; static; inline;
    class function Less(const L, R: widestring): Boolean; static;
  end;

  TUStrHelper = type helper for unicodestring
    class function HashCode(const aValue: unicodestring): SizeInt; static; inline;
    class function Equal(const L, R: unicodestring): Boolean; static; inline;
    class function Less(const L, R: unicodestring): Boolean; static;
  end;

  TShortStrHelper = type helper for shortstring
    class function HashCode(const aValue: shortstring): SizeInt; static; inline;
    class function Equal(const L, R: shortstring): Boolean; static; inline;
    class function Less(const L, R: shortstring): Boolean; static; inline;
  end;

  TGACharHelper = type helper for AnsiChar
    class function HashCode(aValue: AnsiChar): SizeInt; static; inline;
    class function Equal(L, R: AnsiChar): Boolean; static; inline;
    class function Less(L, R: AnsiChar): Boolean; static; inline;
  end;

  TGWCharHelper = type helper for WideChar
    class function HashCode(aValue: WideChar): SizeInt; static; inline;
    class function Equal(L, R: WideChar): Boolean; static; inline;
    class function Less(L, R: WideChar): Boolean; static; inline;
  end;

  TGByteHelper = type helper(TByteHelper) for Byte
    class function HashCode(aValue: Byte): SizeInt; static; inline;
    class function Equal(L, R: Byte): Boolean; static; inline;
    class function Less(L, R: Byte): Boolean; static; inline;
  end;

  TGShortIntHelper = type helper(TShortIntHelper) for ShortInt
    class function HashCode(aValue: ShortInt): SizeInt; static; inline;
    class function Equal(L, R: ShortInt): Boolean; static; inline;
    class function Less(L, R: ShortInt): Boolean; static; inline;
  end;

  TGWordHelper = type helper(TWordHelper) for Word
    class function HashCode(aValue: Word): SizeInt; static; inline;
    class function Equal(L, R: Word): Boolean; static; inline;
    class function Less(L, R: Word): Boolean; static; inline;
  end;

  TGSmallIntHelper = type helper(TSmallIntHelper) for SmallInt
    class function HashCode(aValue: SmallInt): SizeInt; static; inline;
    class function Equal(L, R: SmallInt): Boolean; static; inline;
    class function Less(L, R: SmallInt): Boolean; static; inline;
  end;

  TGDWordHelper = type helper(TCardinalHelper) for DWord
    class function HashCode(aValue: DWord): SizeInt; static; inline;
    class function Equal(L, R: DWord): Boolean; static; inline;
    class function Less(L, R: DWord): Boolean; static; inline;
  end;

  TGLongIntHelper = type helper(TIntegerHelper) for LongInt
    class function HashCode(aValue: LongInt): SizeInt; static; inline;
    class function Equal(L, R: LongInt): Boolean; static; inline;
    class function Less(L, R: LongInt): Boolean; static; inline;
  end;

  TGQWordHelper = type helper(TQWordHelper) for QWord
    class function HashCode(aValue: QWord): SizeInt; static; inline;
    class function Equal(L, R: QWord): Boolean; static; inline;
    class function Less(L, R: QWord): Boolean; static; inline;
  end;

  TGInt64Helper = type helper(TInt64Helper) for Int64
    class function HashCode(aValue: Int64): SizeInt; static; inline;
    class function Equal(L, R: Int64): Boolean; static; inline;
    class function Less(L, R: Int64): Boolean; static; inline;
  end;

  TGNativeUIntHelper = type helper(TNativeUIntHelper) for NativeUInt
    class function HashCode(aValue: NativeUInt): SizeInt; static; inline;
    class function Equal(L, R: NativeUInt): Boolean; static; inline;
    class function Less(L, R: NativeUInt): Boolean; static; inline;
  end;

  TGNativeIntHelper = type helper(TNativeIntHelper) for NativeInt
    class function HashCode(aValue: NativeInt): SizeInt; static; inline;
    class function Equal(L, R: NativeInt): Boolean; static; inline;
    class function Less(L, R: NativeInt): Boolean; static; inline;
  end;

  TGPointerHelper = type helper for Pointer
    class function HashCode(aValue: Pointer): SizeInt; static; inline;
    class function Equal(L, R: Pointer): Boolean; static; inline;
    class function Less(L, R: Pointer): Boolean; static; inline;
  end;

 // currently special float types (nan, infinity) are ignored

  TGSingleHelper = type helper(TSingleHelper) for Single
    function IsZero: Boolean; inline;
    class function HashCode(aValue: Single): SizeInt; static; inline;
    class function Equal(L, R: Single): Boolean; static; inline;
    class function Less(L, R: Single): Boolean; static; inline;
  end;

  TGDoubleHelper = type helper(TDoubleHelper) for Double
    function IsZero: Boolean; inline;
    class function HashCode(aValue: Double): SizeInt; static; inline;
    class function Equal(L, R: Double): Boolean; static; inline;
    class function Less(L, R: Double): Boolean; static; inline;
  end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
  TGExtendedHelper = type helper(TExtendedHelper) for Extended
    function IsZero: Boolean; inline;
    class function HashCode(aValue: Extended): SizeInt; static; inline;
    class function Equal(L, R: Extended): Boolean; static; inline;
    class function Less(L, R: Extended): Boolean; static; inline;
  end;
{$ENDIF}

{$IF DECLARED(Comp)}
  TCompHelper = type helper for Comp
    class function HashCode(aValue: Comp): SizeInt; static; inline;
    class function Equal(L, R: Comp): Boolean; static; inline;
    class function Less(L, R: Comp): Boolean; static; inline;
  end;
{$ENDIF}

  TGDateTimeHelper = type helper for TDateTime
    class function HashCode(aValue: TDateTime): SizeInt; static; inline;
    class function Equal(L, R: TDateTime): Boolean; static; inline;
    class function Less(L, R: TDateTime): Boolean; static; inline;
  end;

  TGDateHelper = type helper for TDate
    class function HashCode(aValue: TDate): SizeInt; static; inline;
    class function Equal(L, R: TDate): Boolean; static; inline;
    class function Less(L, R: TDate): Boolean; static; inline;
  end;

  TGTimeHelper = type helper for TTime
    class function HashCode(aValue: TTime): SizeInt; static; inline;
    class function Equal(L, R: TTime): Boolean; static; inline;
    class function Less(L, R: TTime): Boolean; static; inline;
  end;

  TGCurrencyHelper = type helper for Currency
  const
    MinValue: Currency = -922337203685477.5808;
    MaxValue: Currency = 922337203685477.5807;
    class function HashCode(const aValue: Currency): SizeInt; static; inline;
    class function Equal(const L, R: Currency): Boolean; static; inline;
    class function Less(const L, R: Currency): Boolean; static; inline;
    function ToString: string; inline;
  end;

  TGObjectHelper = class helper for TObject
    class function HashCode(aValue: TObject): SizeInt; static; inline;
    class function Equal(L, R: TObject): Boolean; static; inline;
    class function Less(L, R: TObject): Boolean; static; inline;
  end;

  TVariantHelper = type helper for Variant
    class function HashCode(const aValue: Variant): SizeInt; static; inline;
    class function Equal(const L, R: Variant): Boolean; static; inline;
    class function Less(const L, R: Variant): Boolean; static; inline;
  end;

  TStringArrayHelper = type helper for TStringArray
  private
    function  GetLength: SizeInt;
    procedure SetLen(aValue: SizeInt);
  public
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure Add(const aValue: string);
    property  Length: SizeInt read GetLength write SetLen;
  end;

  TPointHelper = type helper for TPoint
    class function HashCode(const aValue: TPoint): SizeInt; static; inline;
    class function Equal(const L, R: TPoint): Boolean; static; inline;
  end;

  TPrioTaskHelper = type helper for IPriorityTask
    class function Less(L, R: IPriorityTask): Boolean; static; inline;
  end;

  PTypeInfo = TypInfo.PTypeInfo;
  PTypeData = TypInfo.PTypeData;

  generic TGDefaults<T> = class
  public
  type
    TLess           = specialize TGLessCompare<T>;
    TOnLess         = specialize TGOnLessCompare<T>;
    TEqualCompare   = specialize TGEqualCompare<T>;
    TOnEqualCompare = specialize TGOnEqualCompare<T>;

    TComparer = class
      class function Less(const L, R: T): Boolean; static; inline;
    end;

    TEqualityComparer = class
      class function Equal(const L, R: T): Boolean; static; inline;
      class function HashCode(const aValue: T): SizeInt; static; inline;
    end;

  private
  type
    THashCode = function(constref aValue: T): SizeInt;

    TComparator = object
      function LessCompare(const L, R: T): Boolean;
      function EqualCompare(const L, R: T): Boolean;
    end;

  class var
    CFLess: TLess;
    CFEqualCompare: TEqualCompare;
    CFHashCode: THashCode;
    CFComparator: TComparator;
    class constructor Init;
    class procedure InitInt(aData: PTypeData); static;
    class procedure InitFloat(aData: PTypeData); static;
    class function CompareBin(const L, R: T): Boolean; static;
    class function EqualBin(const L, R: T): Boolean; static;
    class function HashBin(const aValue: T): SizeInt; static;
    class function GetOnLess: TOnLess; static; inline;
    class function GetOnEqualCompare: TOnEqualCompare; static; inline;
  public
    class property Less: TLess read CFLess;
    class property EqualCompare: TEqualCompare read CFEqualCompare;
    class property OnLess: TOnLess read GetOnLess;
    class property OnEqualCompare: TOnEqualCompare read GetOnEqualCompare;
  end;

  function CompareShortInt(const L, R: ShortInt): Boolean;
  function CompareUByte(const L, R: Byte): Boolean;
  function CompareSmallInt(const L, R: SmallInt): Boolean;
  function CompareWord(const L, R: Word): Boolean;
  function CompareLongInt(const L, R: LongInt): Boolean;
  function CompareDWord(const L, R: DWord): Boolean;
  function CompareInt64(const L, R: Int64): Boolean;
  function CompareQWord(const L, R: QWord): Boolean;
  function CompareChar(const L, R: AnsiChar): Boolean;
  function CompareSingle(const L, R: Single): Boolean;
  function CompareDouble(const L, R: Double): Boolean;
  function CompareExtended(const L, R: Extended): Boolean;
  {$IF DECLARED(Comp)}
  function CompareComp(const L, R: Comp): Boolean;
  {$ENDIF}
  function CompareCurrency(const L, R: Currency): Boolean;
  function CompareShortStr(const L, R: shortstring): Boolean;
  function CompareLStr(const L, R: string): Boolean;
  function CompareAStr(const L, R: ansistring): Boolean;
  function CompareWStr(const L, R: widestring): Boolean;
  function CompareVariant(const L, R: Variant): Boolean;
  function CompareObj(const L, R: TObject): Boolean;
  function CompareWChar(const L, R: WideChar): Boolean;
  function CompareUStr(const L, R: unicodestring): Boolean;
  function ComparePointer(const L, R: Pointer): Boolean;

  function ShortIntEqual(const L, R: ShortInt): Boolean;
  function UByteEqual(const L, R: Byte): Boolean;
  function SmallIntEqual(const L, R: SmallInt): Boolean;
  function WordEqual(const L, R: Word): Boolean;
  function LongIntEqual(const L, R: LongInt): Boolean;
  function DWordEqual(const L, R: DWord): Boolean;
  function Int64Equal(const L, R: Int64): Boolean;
  function QWordEqual(const L, R: QWord): Boolean;
  function CharEqual(const L, R: AnsiChar): Boolean;
  function SingleEqual(const L, R: Single): Boolean;
  function DoubleEqual(const L, R: Double): Boolean;
  function ExtendedEqual(const L, R: Extended): Boolean;
  function CompEqual(const L, R: Comp): Boolean;
  function CurrencyEqual(const L, R: Currency): Boolean;
  function ShortStrEqual(const L, R: shortstring): Boolean;
  function LStrEqual(const L, R: string): Boolean;
  function AStrEqual(const L, R: ansistring): Boolean;
  function WStrEqual(const L, R: widestring): Boolean;
  function VariantEqual(const L, R: Variant): Boolean;
  function ObjEqual(const L, R: TObject): Boolean;
  function WCharEqual(const L, R: WideChar): Boolean;
  function UStrEqual(const L, R: unicodestring): Boolean;
  function PointerEqual(const L, R: Pointer): Boolean;

  function HashShortInt(const aValue: ShortInt): SizeInt;
  function HashUByte(const aValue: Byte): SizeInt;
  function HashSmallInt(const aValue: SmallInt): SizeInt;
  function HashWord(const aValue: Word): SizeInt;
  function HashLongInt(const aValue: LongInt): SizeInt;
  function HashDWord(const aValue: DWord): SizeInt;
  function HashInt64(const aValue: Int64): SizeInt;
  function HashQWord(const aValue: QWord): SizeInt;
  function HashChar(const aValue: AnsiChar): SizeInt;
  function HashSingle(const aValue: Single): SizeInt;
  function HashDouble(const aValue: Double): SizeInt;
  function HashExtended(const aValue: Extended): SizeInt;
  function HashComp(const aValue: Comp): SizeInt;
  function HashCurrency(const aValue: Currency): SizeInt;
  function HashShortStr(const aValue: shortstring): SizeInt;
  function HashLStr(const aValue: string): SizeInt;
  function HashAStr(const aValue: ansistring): SizeInt;
  function HashWStr(const aValue: widestring): SizeInt;
  function HashVariant(const aValue: Variant): SizeInt;
  function HashObj(const aValue: TObject): SizeInt;
  function HashWChar(const aValue: WideChar): SizeInt;
  function HashUStr(const aValue: unicodestring): SizeInt;
  function HashPointer(const aValue: Pointer): SizeInt;

implementation
{$Q-}{$R-}{$B-}{$COPERATORS ON}{$MACRO ON}
{$DEFINE HashFunc := TxxHash32LE}
{.$DEFINE HashFunc := TMurmur3LE}

class function TGGuidHelper.HashCode(const aValue: TGUID): SizeInt;
begin
  Result := HashFunc.HashGuid(aValue);
end;

class function TGGuidHelper.Equal(const L, R: TGUID): Boolean;
type
  TDWords4 = packed record
    D1, D2, D3, D4: DWord;
  end;
var
  dL: TDWords4 absolute L;
  dR: TDWords4 absolute R;
begin
  if @L = @R then
    exit(True);
  Result := (dL.D1 = dR.D1) and (dL.D2 = dR.D2) and (dL.D3 = dR.D3) and (dL.D4 = dR.D4);
end;

class function TGGuidHelper.Less(const L, R: TGUID): Boolean;
begin
  Result := CompareMemRange(@L, @R, SizeOf(TGUID)) < 0;
end;

{ TStrHelper }

class function TStrHelper.HashCode(const aValue: string): SizeInt;
begin
  Result := HashFunc.HashStr(aValue);
end;

class function TStrHelper.Equal(const L, R: string): Boolean;
begin
  Result := L = R;
end;

class function TStrHelper.Less(const L, R: string): Boolean;
begin
  Result := CompareStr(L, R) < 0;
end;

class function TAStrHelper.HashCode(const aValue: ansistring): SizeInt;
begin
  Result := HashFunc.HashStr(aValue);
end;

class function TAStrHelper.Equal(const L, R: ansistring): Boolean;
begin
  Result := L = R;
end;

class function TAStrHelper.Less(const L, R: ansistring): Boolean;
begin
  //Result := StrComp(PAnsiChar(L), PAnsiChar(R));
  Result := AnsiCompareStr(L, R) < 0;
end;

class function TWStrHelper.HashCode(const aValue: widestring): SizeInt;
begin
  Result := HashFunc.HashBuf(PWideChar(aValue), System.Length(aValue) * SizeOf(System.WideChar));
end;

class function TWStrHelper.Equal(const L, R: widestring): Boolean;
begin
  Result := L = R;
end;

class function TWStrHelper.Less(const L, R: widestring): Boolean;
begin
  //Result := StrComp(PWideChar(L), PWideChar(R));
  Result := WideCompareStr(L, R) < 0;
end;

class function TUStrHelper.HashCode(const aValue: unicodestring): SizeInt;
begin
  Result := HashFunc.HashBuf(PUnicodeChar(aValue), System.Length(aValue) * SizeOf(System.UnicodeChar));
end;

class function TUStrHelper.Equal(const L, R: unicodestring): Boolean;
begin
  Result := L = R;
end;

class function TUStrHelper.Less(const L, R: unicodestring): Boolean;
begin
  Result := UnicodeCompareStr(L, R) < 0;
end;

class function TShortStrHelper.HashCode(const aValue: shortstring): SizeInt;
begin
  Result := HashFunc.HashBuf(@aValue[1], System.Length(aValue));
end;

class function TShortStrHelper.Equal(const L, R: shortstring): Boolean;
begin
  Result := L = R;
end;

class function TShortStrHelper.Less(const L, R: shortstring): Boolean;
begin
  Result := L < R;
end;

class function TGACharHelper.HashCode(aValue: AnsiChar): SizeInt;
begin
  Result := Ord(aValue) xor Ord(aValue) shr 5;
end;

class function TGACharHelper.Equal(L, R: AnsiChar): Boolean;
begin
  Result := L = R;
end;

class function TGACharHelper.Less(L, R: AnsiChar): Boolean;
begin
  Result := L < R;
end;

class function TGWCharHelper.HashCode(aValue: WideChar): SizeInt;
begin
  Result := HashFunc.HashWord(Ord(aValue));
end;

class function TGWCharHelper.Equal(L, R: WideChar): Boolean;
begin
  Result := L = R;
end;

class function TGWCharHelper.Less(L, R: WideChar): Boolean;
begin
  Result := L < R;
end;

class function TGByteHelper.HashCode(aValue: Byte): SizeInt;
begin
  Result := aValue xor aValue shr 5;
end;

class function TGByteHelper.Equal(L, R: Byte): Boolean;
begin
  Result := L = R;
end;

class function TGByteHelper.Less(L, R: Byte): Boolean;
begin
  Result := L < R;
end;

class function TGShortIntHelper.HashCode(aValue: ShortInt): SizeInt;
begin
  Result := Byte.HashCode(aValue);
end;

class function TGShortIntHelper.Equal(L, R: ShortInt): Boolean;
begin
  Result := L = R;
end;

class function TGShortIntHelper.Less(L, R: ShortInt): Boolean;
begin
  Result := L < R;
end;

class function TGWordHelper.HashCode(aValue: Word): SizeInt;
begin
  Result := HashFunc.HashWord(aValue);
end;

class function TGWordHelper.Equal(L, R: Word): Boolean;
begin
  Result := L = R;
end;

class function TGWordHelper.Less(L, R: Word): Boolean;
begin
  Result := L < R;
end;

class function TGSmallIntHelper.HashCode(aValue: SmallInt): SizeInt;
begin
  Result := HashFunc.HashWord(aValue);
end;

class function TGSmallIntHelper.Equal(L, R: SmallInt): Boolean;
begin
  Result := L = R;
end;

class function TGSmallIntHelper.Less(L, R: SmallInt): Boolean;
begin
  Result := L < R;
end;

class function TGDWordHelper.HashCode(aValue: DWord): SizeInt;
begin
  Result := HashFunc.HashDWord(aValue);
end;

class function TGDWordHelper.Equal(L, R: DWord): Boolean;
begin
  Result := L = R;
end;

class function TGDWordHelper.Less(L, R: DWord): Boolean;
begin
  Result := L < R;
end;

class function TGLongIntHelper.HashCode(aValue: LongInt): SizeInt;
begin
  Result := HashFunc.HashDWord(aValue);
end;

class function TGLongIntHelper.Equal(L, R: LongInt): Boolean;
begin
  Result := L = R;
end;

class function TGLongIntHelper.Less(L, R: LongInt): Boolean;
begin
  Result := L < R;
end;

class function TGQWordHelper.HashCode(aValue: QWord): SizeInt;
begin
  Result := HashFunc.HashQWord(aValue);
end;

class function TGQWordHelper.Equal(L, R: QWord): Boolean;
begin
  Result := L = R;
end;

class function TGQWordHelper.Less(L, R: QWord): Boolean;
begin
  Result := L < R;
end;

class function TGInt64Helper.HashCode(aValue: Int64): SizeInt;
begin
  Result := HashFunc.HashQWord(aValue);
end;

class function TGInt64Helper.Equal(L, R: Int64): Boolean;
begin
  Result := L = R;
end;

class function TGInt64Helper.Less(L, R: Int64): Boolean;
begin
  Result := L < R;
end;

class function TGNativeUIntHelper.HashCode(aValue: NativeUInt): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := HashFunc.HashQWord(aValue);
{$ELSEIF DEFINED(CPU32)}
  Result := HashFunc.HashDWord(aValue);
{$ELSE}
  Result := HashFunc.HashWord(aValue);
{$ENDIF}
end;

class function TGNativeUIntHelper.Equal(L, R: NativeUInt): Boolean;
begin
  Result := L = R;
end;

class function TGNativeUIntHelper.Less(L, R: NativeUInt): Boolean;
begin
  Result := L < R;
end;

class function TGNativeIntHelper.HashCode(aValue: NativeInt): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := HashFunc.HashQWord(aValue);
{$ELSEIF DEFINED(CPU32)}
  Result := HashFunc.HashDWord(aValue);
{$ELSE}
  Result := HashFunc.HashWord(aValue);
{$ENDIF}
end;

class function TGNativeIntHelper.Equal(L, R: NativeInt): Boolean;
begin
  Result := L = R;
end;

class function TGNativeIntHelper.Less(L, R: NativeInt): Boolean;
begin
  Result := L < R;
end;

class function TGPointerHelper.HashCode(aValue: Pointer): SizeInt;
begin
  Result := SizeUInt.HashCode({%H-}SizeUInt(aValue));
end;

class function TGPointerHelper.Equal(L, R: Pointer): Boolean;
begin
  Result := L = R;
end;

class function TGPointerHelper.Less(L, R: Pointer): Boolean;
begin
  Result := L < R;
end;

function TGSingleHelper.IsZero: Boolean;
begin
  Result:= (DWord(Self) and $7fffffff) = 0;
end;

class function TGSingleHelper.HashCode(aValue: Single): SizeInt;
begin
  if aValue.IsZero then
    Result := HashFunc.HashDWord(DWord(Single(0.0)))
  else
    Result := HashFunc.HashDWord(DWord(aValue));
end;

class function TGSingleHelper.Equal(L, R: Single): Boolean;
begin
  Result := L = R;
end;

class function TGSingleHelper.Less(L, R: Single): Boolean;
begin
  Result := L < R;
end;

function TGDoubleHelper.IsZero: Boolean;
begin
  Result := (QWord(Self) and $7fffffffffffffff) = 0;
end;

class function TGDoubleHelper.HashCode(aValue: Double): SizeInt;
begin
  if aValue.IsZero then
    Result := HashFunc.HashQWord(QWord(Double(0.0)))
  else
    Result := HashFunc.HashQWord(QWord(aValue));
end;

class function TGDoubleHelper.Equal(L, R: Double): Boolean;
begin
  Result := L = R;
end;

class function TGDoubleHelper.Less(L, R: Double): Boolean;
begin
  Result := L < R;
end;
{$ifdef FPC_HAS_TYPE_EXTENDED}
function TGExtendedHelper.IsZero: Boolean;
begin
  Result := SpecialType < fsDenormal;
end;

class function TGExtendedHelper.HashCode(aValue: Extended): SizeInt;
const
  Zero: Extended = 0.0;
begin
  if aValue.IsZero then
    Result := HashFunc.HashBuf(@Zero, SizeOf(Zero))
  else
    Result := HashFunc.HashBuf(@aValue, SizeOf(aValue));
end;

class function TGExtendedHelper.Equal(L, R: Extended): Boolean;
begin
  Result := L = R;
end;

class function TGExtendedHelper.Less(L, R: Extended): Boolean;
begin
  Result := L < R;
end;
{$ENDIF}

{$IF DECLARED(Comp)}
{ TCompHelper }

class function TCompHelper.HashCode(aValue: Comp): SizeInt;
begin
  Result := QWord.HashCode(QWord(aValue));
end;

class function TCompHelper.Equal(L, R: Comp): Boolean;
begin
  Result := L = R;
end;

class function TCompHelper.Less(L, R: Comp): Boolean;
begin
  Result := L < R;
end;
{$ENDIF}

class function TGDateTimeHelper.HashCode(aValue: TDateTime): SizeInt;
begin
  Result := HashFunc.HashQWord(QWord(aValue));
end;

class function TGDateTimeHelper.Equal(L, R: TDateTime): Boolean;
begin
  Result := L = R;
end;

class function TGDateTimeHelper.Less(L, R: TDateTime): Boolean;
begin
  Result := L < R;
end;

class function TGDateHelper.HashCode(aValue: TDate): SizeInt;
begin
  Result := HashFunc.HashQWord(QWord(aValue));
end;

class function TGDateHelper.Equal(L, R: TDate): Boolean;
begin
  Result := L = R;
end;

class function TGDateHelper.Less(L, R: TDate): Boolean;
begin
  Result := L < R;
end;

class function TGTimeHelper.HashCode(aValue: TTime): SizeInt;
begin
  Result := HashFunc.HashQWord(QWord(aValue));
end;

class function TGTimeHelper.Equal(L, R: TTime): Boolean;
begin
  Result := L = R;
end;

class function TGTimeHelper.Less(L, R: TTime): Boolean;
begin
  Result := L < R;
end;

class function TGCurrencyHelper.HashCode(const aValue: Currency): SizeInt;
begin
  Result := HashFunc.HashQWord(QWord(aValue));
end;

class function TGCurrencyHelper.Equal(const L, R: Currency): Boolean;
begin
  Result := L = R;
end;

class function TGCurrencyHelper.Less(const L, R: Currency): Boolean;
begin
  Result := L < R;
end;

function TGCurrencyHelper.ToString: string;
begin
  Result := CurrToStr(Self);
end;

class function TGObjectHelper.HashCode(aValue: TObject): SizeInt;
begin
{$IF DEFINED(CPU64)}
  if aValue <> nil then
    Result := HashFunc.HashQWord(aValue.GetHashCode)
  else
    Result := HashFunc.HashQWord(0);
{$ELSEIF DEFINED(CPU32)}
  if aValue <> nil then
    Result := HashFunc.HashDWord(aValue.GetHashCode)
  else
    Result := HashFunc.HashDWord(0);
{$ELSE}
  if aValue <> nil then
    Result := HashFunc.HashWord(aValue.GetHashCode)
  else
    Result := HashFunc.HashWord(0);
{$ENDIF}
end;

class function TGObjectHelper.Equal(L, R: TObject): Boolean;
begin
  Result := L.Equals(R);
end;

class function TGObjectHelper.Less(L, R: TObject): Boolean;
begin
  Result := Pointer(L) < Pointer(R);
end;

class function TVariantHelper.HashCode(const aValue: Variant): SizeInt;
begin
  Result := HashFunc.HashBuf(@aValue, SizeOf(System.Variant), 0);
end;

class function TVariantHelper.Equal(const L, R: Variant): Boolean;
begin
  Result := VarCompareValue(L, R) = vrEqual;
end;

class function TVariantHelper.Less(const L, R: Variant): Boolean;
begin
  Result := VarCompareValue(L, R) = vrLessThan;
end;

function TStringArrayHelper.GetLength: SizeInt;
begin
  Result := System.Length(Self);
end;

procedure TStringArrayHelper.SetLen(aValue: SizeInt);
begin
  System.SetLength(Self, aValue);
end;

function TStringArrayHelper.IsEmpty: Boolean;
begin
  Result := Self = nil;
end;

function TStringArrayHelper.NonEmpty: Boolean;
begin
  Result := Self <> nil;
end;

procedure TStringArrayHelper.Add(const aValue: string);
var
  len: SizeInt;
begin
  len := System.Length(Self);
  System.SetLength(Self, len + 1);
  Self[len] := aValue;
end;

{ TPointHelper }

class function TPointHelper.HashCode(const aValue: TPoint): SizeInt;
begin
{$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := HashFunc.HashQWord(QWord(aValue));
{$ELSE }
  Result := HashFunc.HashBuf(@aValue, SizeOf(aValue));
{$ENDIF }
end;

class function TPointHelper.Equal(const L, R: TPoint): Boolean;
begin
  Result := L = R;
end;

{ TPrioTaskHelper }

class function TPrioTaskHelper.Less(L, R: IPriorityTask): Boolean;
begin
  Result := L.GetPriority < R.GetPriority;
end;

function CompareShortInt(const L, R: ShortInt): Boolean;
begin
  Result := ShortInt.Less(L, R);
end;

function CompareUByte(const L, R: Byte): Boolean;
begin
  Result := Byte.Less(L, R);
end;

function CompareSmallInt(const L, R: SmallInt): Boolean;
begin
  Result := SmallInt.Less(L, R);
end;

function CompareWord(const L, R: Word): Boolean;
begin
  Result := Word.Less(L, R);
end;

function CompareLongInt(const L, R: LongInt): Boolean;
begin
  Result := LongInt.Less(L, R);
end;

function CompareDWord(const L, R: DWord): Boolean;
begin
  Result := DWord.Less(L, R);
end;

function CompareInt64(const L, R: Int64): Boolean;
begin
  Result := Int64.Less(L, R);
end;

function CompareQWord(const L, R: QWord): Boolean;
begin
  Result := QWord.Less(L, R);
end;

function CompareChar(const L, R: AnsiChar): Boolean;
begin
  Result := AnsiChar.Less(L, R);
end;

function CompareSingle(const L, R: Single): Boolean;
begin
  Result := Single.Less(L, R);
end;

function CompareDouble(const L, R: Double): Boolean;
begin
  Result := Double.Less(L, R);
end;

function CompareExtended(const L, R: Extended): Boolean;
begin
  Result := Extended.Less(L, R);
end;

{$IF DECLARED(Comp)}
function CompareComp(const L, R: Comp): Boolean;
begin
  Result := Comp.Less(L, R);
end;
{$ENDIF}

function CompareCurrency(const L, R: Currency): Boolean;
begin
  Result := Currency.Less(L, R);
end;

function CompareShortStr(const L, R: shortstring): Boolean;
begin
  Result := shortstring.Less(L, R);
end;

function CompareLStr(const L, R: string): Boolean;
begin
  Result := ansistring.Less(L, R);
end;

function CompareAStr(const L, R: ansistring): Boolean;
begin
  Result := ansistring.Less(L, R);
end;

function CompareWStr(const L, R: widestring): Boolean;
begin
  Result := widestring.Less(L, R);
end;

function CompareVariant(const L, R: Variant): Boolean;
begin
  Result := Variant.Less(L, R);
end;

function CompareObj(const L, R: TObject): Boolean;
begin
  Result := TObject.Less(L, R);
end;

function CompareWChar(const L, R: WideChar): Boolean;
begin
  Result := WideChar.Less(L, R);
end;

function CompareUStr(const L, R: unicodestring): Boolean;
begin
  Result := unicodestring.Less(L, R);
end;

function ComparePointer(const L, R: Pointer): Boolean;
begin
  Result := Pointer.Less(L, R);
end;

function ShortIntEqual(const L, R: ShortInt): Boolean;
begin
  Result := ShortInt.Equal(L, R);
end;

function UByteEqual(const L, R: Byte): Boolean;
begin
  Result := Byte.Equal(L, R);
end;

function SmallIntEqual(const L, R: SmallInt): Boolean;
begin
  Result := SmallInt.Equal(L, R);
end;

function WordEqual(const L, R: Word): Boolean;
begin
  Result := Word.Equal(L, R);
end;

function LongIntEqual(const L, R: LongInt): Boolean;
begin
  Result := LongInt.Equal(L, R);
end;

function DWordEqual(const L, R: DWord): Boolean;
begin
  Result := DWord.Equal(L, R);
end;

function Int64Equal(const L, R: Int64): Boolean;
begin
  Result := Int64.Equal(L, R);
end;

function QWordEqual(const L, R: QWord): Boolean;
begin
  Result := QWord.Equal(L, R);
end;

function CharEqual(const L, R: AnsiChar): Boolean;
begin
  Result := AnsiChar.Equal(L, R);
end;

function SingleEqual(const L, R: Single): Boolean;
begin
  Result := Single.Equal(L, R);
end;

function DoubleEqual(const L, R: Double): Boolean;
begin
  Result := Double.Equal(L, R);
end;

function ExtendedEqual(const L, R: Extended): Boolean;
begin
  Result := Extended.Equal(L, R);
end;

function CompEqual(const L, R: Comp): Boolean;
begin
  Result := Comp.Equal(L, R);
end;

function CurrencyEqual(const L, R: Currency): Boolean;
begin
  Result := Currency.Equal(L, R);
end;

function ShortStrEqual(const L, R: shortstring): Boolean;
begin
  Result := shortstring.Equal(L, R);
end;

function LStrEqual(const L, R: string): Boolean;
begin
  Result := ansistring.Equal(L, R);
end;

function AStrEqual(const L, R: ansistring): Boolean;
begin
  Result := ansistring.Equal(L, R);
end;

function WStrEqual(const L, R: widestring): Boolean;
begin
  Result := widestring.Equal(L, R);
end;

function VariantEqual(const L, R: Variant): Boolean;
begin
  Result := Variant.Equal(L, R);
end;

function ObjEqual(const L, R: TObject): Boolean;
begin
  Result := TObject.Equal(L, R);
end;

function WCharEqual(const L, R: WideChar): Boolean;
begin
  Result := WideChar.Equal(L, R);
end;

function UStrEqual(const L, R: unicodestring): Boolean;
begin
  Result := unicodestring.Equal(L, R);
end;

function PointerEqual(const L, R: Pointer): Boolean;
begin
  Result := Pointer.Equal(L, R);
end;

function HashShortInt(const aValue: ShortInt): SizeInt;
begin
  Result := ShortInt.HashCode(aValue);
end;

function HashUByte(const aValue: Byte): SizeInt;
begin
  Result := Byte.HashCode(aValue);
end;

function HashSmallInt(const aValue: SmallInt): SizeInt;
begin
  Result := SmallInt.HashCode(aValue);
end;

function HashWord(const aValue: Word): SizeInt;
begin
  Result := Word.HashCode(aValue);
end;

function HashLongInt(const aValue: LongInt): SizeInt;
begin
  Result := LongInt.HashCode(aValue);
end;

function HashDWord(const aValue: DWord): SizeInt;
begin
  Result := DWord.HashCode(aValue);
end;

function HashInt64(const aValue: Int64): SizeInt;
begin
  Result := Int64.HashCode(aValue);
end;

function HashQWord(const aValue: QWord): SizeInt;
begin
  Result := QWord.HashCode(aValue);
end;

function HashChar(const aValue: AnsiChar): SizeInt;
begin
  Result := AnsiChar.HashCode(aValue);
end;

function HashSingle(const aValue: Single): SizeInt;
begin
  Result := Single.HashCode(aValue);
end;

function HashDouble(const aValue: Double): SizeInt;
begin
  Result := Double.HashCode(aValue);
end;

function HashExtended(const aValue: Extended): SizeInt;
begin
  Result := Extended.HashCode(aValue);
end;

function HashComp(const aValue: Comp): SizeInt;
begin
  Result := Comp.HashCode(aValue);
end;

function HashCurrency(const aValue: Currency): SizeInt;
begin
  Result := Currency.HashCode(aValue);
end;

function HashShortStr(const aValue: shortstring): SizeInt;
begin
  Result := shortstring.HashCode(aValue);
end;

function HashLStr(const aValue: string): SizeInt;
begin
  Result := ansistring.HashCode(aValue);
end;

function HashAStr(const aValue: ansistring): SizeInt;
begin
  Result := ansistring.HashCode(aValue);
end;

function HashWStr(const aValue: widestring): SizeInt;
begin
  Result := widestring.HashCode(aValue);
end;

function HashVariant(const aValue: Variant): SizeInt;
begin
  Result := Variant.HashCode(aValue);
end;

function HashObj(const aValue: TObject): SizeInt;
begin
  Result := TObject.HashCode(aValue);
end;

function HashWChar(const aValue: WideChar): SizeInt;
begin
  Result := WideChar.HashCode(aValue);
end;

function HashUStr(const aValue: unicodestring): SizeInt;
begin
  Result := unicodestring.HashCode(aValue);
end;

function HashPointer(const aValue: Pointer): SizeInt;
begin
  Result := Pointer.HashCode(aValue);
end;

{ TGDefaults.TComparer }

class function TGDefaults.TComparer.Less(const L, R: T): Boolean;
begin
  Result := CFLess(L, R);
end;

{ TGDefaults.TEqualityComparer }

class function TGDefaults.TEqualityComparer.Equal(const L, R: T): Boolean;
begin
  Result := CFEqualCompare(L, R);
end;

class function TGDefaults.TEqualityComparer.HashCode(const aValue: T): SizeInt;
begin
  Result := CFHashCode(aValue);
end;

{ TGDefaults.TComparator }

function TGDefaults.TComparator.LessCompare(const L, R: T): Boolean;
begin
  Result := CFLess(L, R);
end;

function TGDefaults.TComparator.EqualCompare(const L, R: T): Boolean;
begin
  Result := CFEqualCompare(L, R);
end;

{ TGDefaultComparer }

class constructor TGDefaults.Init;
var
  p: PTypeInfo;
begin
  p := System.TypeInfo(T);
  if p <> nil then
    case p^.Kind of
      tkInteger:
        InitInt(GetTypeData(p));
      tkChar:
        begin
          CFLess := TLess(@CompareChar);
          CFEqualCompare := TEqualCompare(@CharEqual);
          CFHashCode := THashCode(@HashChar);
        end;
      tkFloat:
        InitFloat(GetTypeData(p));
      tkSString:
        begin
          CFLess := TLess(@CompareShortStr);
          CFEqualCompare := TEqualCompare(@ShortStrEqual);
          CFHashCode := THashCode(@HashShortStr);
        end;
      tkLString:
        begin
          CFLess := TLess(@CompareLStr);
          CFEqualCompare := TEqualCompare(@LStrEqual);
          CFHashCode := THashCode(@HashLStr);
        end;
      tkAString:
        begin
          CFLess := TLess(@CompareAStr);
          CFEqualCompare := TEqualCompare(@AStrEqual);
          CFHashCode := THashCode(@HashAStr);
        end;
      tkWString:
        begin
          CFLess := TLess(@CompareWStr);
          CFEqualCompare := TEqualCompare(@WStrEqual);
          CFHashCode := THashCode(@HashWStr);
        end;
      tkVariant:
        begin
          CFLess := TLess(@CompareVariant);
          CFEqualCompare := TEqualCompare(@VariantEqual);
          CFHashCode := THashCode(@HashVariant);
        end;
      tkClass:
        begin
          CFLess := TLess(@CompareObj);
          CFEqualCompare := TEqualCompare(@ObjEqual);
          CFHashCode := THashCode(@HashObj);
        end;
      tkWChar:
        begin
          CFLess := TLess(@CompareWChar);
          CFEqualCompare := TEqualCompare(@WCharEqual);
          CFHashCode := THashCode(@HashWChar);
        end;
      tkInt64:
        begin
          CFLess := TLess(@CompareInt64);
          CFEqualCompare := TEqualCompare(@Int64Equal);
          CFHashCode := THashCode(@HashInt64);
        end;
      tkQWord:
        begin
          CFLess := TLess(@CompareQWord);
          CFEqualCompare := TEqualCompare(@QWordEqual);
          CFHashCode := THashCode(@HashQWord);
        end;
      tkUString:
        begin
          CFLess := TLess(@CompareUStr);
          CFEqualCompare := TEqualCompare(@UStrEqual);
          CFHashCode := THashCode(@HashUStr);
        end;
      tkUChar:
        begin
          CFLess := TLess(@CompareWChar);
          CFEqualCompare := TEqualCompare(@WCharEqual);
          CFHashCode := THashCode(@HashWChar);
        end;
      tkPointer:
        begin
          CFLess := TLess(@ComparePointer);
          CFEqualCompare := TEqualCompare(@PointerEqual);
          CFHashCode := THashCode(@HashPointer);
        end;
    else
      CFLess := TLess(@CompareBin);
      CFEqualCompare := TEqualCompare(@EqualBin);
      CFHashCode := THashCode(@HashBin);
    end
  else
    begin
      CFLess := TLess(@CompareBin);
      CFEqualCompare := TEqualCompare(@EqualBin);
      CFHashCode := THashCode(@HashBin);
    end;
end;

class procedure TGDefaults.InitInt(aData: PTypeData);
begin
  case aData^.OrdType of
    otSByte:
      begin
        CFLess := TLess(@CompareShortInt);
        CFEqualCompare := TEqualCompare(@ShortIntEqual);
        CFHashCode := THashCode(@HashShortInt);
      end;
    otUByte:
      begin
        CFLess := TLess(@CompareUByte);
        CFEqualCompare := TEqualCompare(@UByteEqual);
        CFHashCode := THashCode(@HashUByte);
      end;
    otSWord:
      begin
        CFLess := TLess(@CompareSmallInt);
        CFEqualCompare := TEqualCompare(@SmallIntEqual);
        CFHashCode := THashCode(@HashSmallInt);
      end;
    otUWord:
      begin
        CFLess := TLess(@CompareWord);
        CFEqualCompare := TEqualCompare(@WordEqual);
        CFHashCode := THashCode(@HashWord);
      end;
    otSLong:
      begin
        CFLess := TLess(@CompareLongInt);
        CFEqualCompare := TEqualCompare(@LongIntEqual);
        CFHashCode := THashCode(@HashLongInt);
      end;
    otULong:
      begin
        CFLess := TLess(@CompareDWord);
        CFEqualCompare := TEqualCompare(@DWordEqual);
        CFHashCode := THashCode(@HashDWord);
      end;
    otSQWord:
      begin
        CFLess := TLess(@CompareInt64);
        CFEqualCompare := TEqualCompare(@Int64Equal);
        CFHashCode := THashCode(@HashInt64);
      end;
    otUQWord:
      begin
        CFLess := TLess(@CompareQWord);
        CFEqualCompare := TEqualCompare(@QWordEqual);
        CFHashCode := THashCode(@HashQWord);
      end;
  end;
end;

class procedure TGDefaults.InitFloat(aData: PTypeData);
begin
  case aData^.FloatType of
    ftSingle:
      begin
        CFLess := TLess(@CompareSingle);
        CFEqualCompare := TEqualCompare(@SingleEqual);
        CFHashCode := THashCode(@HashSingle);
      end;
    ftDouble:
      begin
        CFLess := TLess(@CompareDouble);
        CFEqualCompare := TEqualCompare(@DoubleEqual);
        CFHashCode := THashCode(@HashDouble);
      end;
    ftExtended:
      begin
        CFLess := TLess(@CompareExtended);
        CFEqualCompare := TEqualCompare(@ExtendedEqual);
        CFHashCode := THashCode(@HashExtended);
      end;
    ftComp:
      begin
        CFLess := TLess(@CompareComp);
        CFEqualCompare := TEqualCompare(@CompEqual);
        CFHashCode := THashCode(@HashComp);
      end;
    ftCurr:
      begin
        CFLess := TLess(@CompareCurrency);
        CFEqualCompare := TEqualCompare(@CurrencyEqual);
        CFHashCode := THashCode(@HashCurrency);
      end;
  end;
end;

class function TGDefaults.CompareBin(const L, R: T): Boolean;
begin
  Result := CompareMemRange(@L, @R, SizeOf(T)) < 0;
end;

class function TGDefaults.EqualBin(const L, R: T): Boolean;
begin
  Result := CompareMemRange(@L, @R, SizeOf(T)) = 0;
end;

class function TGDefaults.HashBin(const aValue: T): SizeInt;
begin
  Result := HashFunc.HashBuf(@aValue, SizeOf(T));
end;

class function TGDefaults.GetOnLess: TOnLess;
begin
  Result := @CFComparator.LessCompare;
end;

class function TGDefaults.GetOnEqualCompare: TOnEqualCompare;
begin
  Result := @CFComparator.EqualCompare;
end;

end.

