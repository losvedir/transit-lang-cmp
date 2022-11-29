{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   128-bit integers implementation.                                        *
*                                                                           *
*   Copyright(c) 2019-2022 A.Koverdyaev(avk)                                *
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
unit lgInt128;

{$mode objfpc}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$INLINE ON}

interface
uses
  SysUtils, Math, SysConst, lgUtils;

{$IFDEF ENDIAN_BIG}
  {$FATAL Big Endian is not supported }
{$ENDIF}
{$IF DEFINED(CPUX64) OR DEFINED(CPUI386)}
  {$DEFINE CPU_INTEL}
  {$IFDEF CPUX64}
    {$DEFINE USE_LIMB64}
  {$ENDIF CPUX64}
{$ENDIF} {.$Q+}{.$R+}

type

  { TUInt128 }
  TUInt128 = record
  private
  const
  {$IFDEF USE_LIMB64}
  type
    TLimb                = QWord;
  {$ELSE USE_LIMB64}
  type
    TLimb                = DWord;
  {$ENDIF USE_LIMB64}
  const
  {$IFDEF USE_LIMB64}
    LIMB_SIZE_LOG        = 6;
    STR_CONV_BASE: TLimb = TLimb(10000000000000000000);
    STR_CONV_BASE_LOG    = 19;
    LIMB_PER_VALUE       = 2;
  {$ELSE USE_LIMB64}
    LIMB_SIZE_LOG        = 5;
    STR_CONV_BASE: TLimb = TLimb(1000000000);
    STR_CONV_BASE_LOG    = 9;
    LIMB_PER_VALUE       = 4;
  {$ENDIF USE_LIMB64}
    MAX_LIMB             = High(TLimb);
    BIT_PER_LIMB         = BitSizeOf(TLimb);
    LIMB_BITSIZE_MASK    = BIT_PER_LIMB - 1;
    DWORD_PER_VALUE      = 4;
    BYTE_PER_VALUE       = 16;
    BIT_PER_VALUE        = 128;
    VALUE_BITSIZE_MASK   = Pred(BIT_PER_VALUE);
  type
    PLimb                = ^TLimb;
    TLimbs128            = array[0..Pred(LIMB_PER_VALUE)] of TLimb;
    TLimbsEx             = array[0..LIMB_PER_VALUE] of TLimb;
    TCompare             = type TValueSign;
    TParseResult         = (prDec, prHex, prZero, prNan);
  var
    FLimbs: TLimbs128;
    function  GetBit(aIndex: Integer): Boolean; inline;
    procedure SetBit(aIndex: Integer; aValue: Boolean); inline;
    function  GetByte(aIndex: Integer): Byte; inline;
    procedure SetByte(aIndex: Integer; aValue: Byte); inline;
    function  GetDWord(aIndex: Integer): DWord; inline;
    procedure SetDWord(aIndex: Integer; aValue: DWord); inline;
    class function  Cmp(const a, b: TLimbs128): TCompare; static;
    class function  MsBitIndex(const aValue: TLimbs128): Integer; static;
    class function  MsLimbIndex(const aValue: TLimbs128): Integer; static;
    class function  NlzLimb(aValue: TLimb): Integer; static; inline;
    class procedure SetSingleLimb(aLimb: TLimb; out aValue: TLimbs128); static; inline;
    class procedure DoNeg(a: PLimb; n: PLimb); static;
    class function  DoAdd(a, b, s: PLimb): TLimb; static;
    class function  DoAddShort(a: PLimb; b: TLimb; s: PLimb): TLimb; static;
    class function  DoSub(a, b, d: PLimb): TLimb; static;
    class function  DoSubShort(a: PLimb; b: TLimb; d: PLimb): TLimb; static;
    { simple schoolbook multiplication }
    class function  DoMul(a, b, p: PLimb): TLimb; static;
    class function  DoMulShort(a: PLimb; b: TLimb; p: PLimb): TLimb; static;
    { does not supports same a and r; does not checks if aDist < BIT_PER_LIMB }
    class function  ShortBitShiftLeft(a, r: PLimb; aDist: Integer): TLimb; static;
    { does not supports same a and r; does not checks if aDist < BIT_PER_LIMB }
    class procedure ShortBitShiftRight(a, r: PLimb; aDist: Integer); static;
    { does not supports same a and r }
    class procedure BitShiftLeft(a, r: PLimb; aDist: Integer); static;
    { does not supports same a and r }
    class procedure BitShiftRight(a, r: PLimb; aDist: Integer); static;
    { DEK's schoolbook division algorithm }
    class procedure DoDiv(r, d, q: PLimb); static;
    class procedure Divide(const a, d: TUInt128; dMsLimbIdx: Integer; out q, r: TUInt128); static;
    class procedure DivQ(const a, d: TUInt128; dMsLimbIdx: Integer; out q: TUInt128); static;
    class procedure DivR(const a, d: TUInt128; dMsLimbIdx: Integer; out r: TUInt128); static;
    class function  DoDivShort(a: PLimb; d: TLimb; q: PLimb): TLimb; static;
    class function  Limb2Str(aValue: TLimb; aStr: PAnsiChar; aShowLz: Boolean = True): Integer; static;
    class function  Str2Limb(aValue: PAnsiChar; aCount: Integer): TLimb; static;
    class function  ParseStr(const aValue: string; out aResult: shortstring): TParseResult; static;
    class function  TryParseStr(const s: string; out aValue: TLimbs128): Boolean; static;
    class function  TryDec2Val(const s: shortstring; out aValue: TLimbs128): Boolean; static;
    class procedure Hex2Val(const s: shortstring; out aValue: TLimbs128); static;
    class function  Val2Str(const aValue: TLimbs128): string; static;
    class function  Val2Hex(const aValue: TLimbs128; aMinDigits: Integer; aShowRadix: Boolean): string; static;
  public
    class operator  = (const L, R: TUInt128): Boolean;
    class operator  <>(const L, R: TUInt128): Boolean;
    class operator  > (const L, R: TUInt128): Boolean; inline;
    class operator  >=(const L, R: TUInt128): Boolean; inline;
    class operator  < (const L, R: TUInt128): Boolean; inline;
    class operator  <=(const L, R: TUInt128): Boolean; inline;

    class operator  = (const L: TUInt128; R: DWord): Boolean;
    class operator  <>(const L: TUInt128; R: DWord): Boolean;
    class operator  > (const L: TUInt128; R: DWord): Boolean;
    class operator  >=(const L: TUInt128; R: DWord): Boolean;
    class operator  < (const L: TUInt128; R: DWord): Boolean;
    class operator  <=(const L: TUInt128; R: DWord): Boolean;

    class operator  :=(const aValue: DWord): TUInt128;
    class operator  :=(const aValue: string): TUInt128; inline;
    class operator  :=(const aValue: TUInt128): Double; inline;
    class operator  :=(const aValue: TUInt128): string; inline;

    class operator  Inc(const aValue: TUInt128): TUInt128; inline;
    class operator  Dec(const aValue: TUInt128): TUInt128; inline;
    class operator  shl(const aValue: TUInt128; aDist: Integer): TUInt128;
    class operator  shr(const aValue: TUInt128; aDist: Integer): TUInt128;
    class operator  not(const aValue: TUInt128): TUInt128;
    class operator  and(const L, R: TUInt128): TUInt128;
    class operator  or (const L, R: TUInt128): TUInt128;
    class operator  xor(const L, R: TUInt128): TUInt128;
    class operator  and(const L: TUInt128; R: DWord): TUInt128;
    class operator  or (const L: TUInt128; R: DWord): TUInt128;
    class operator  xor(const L: TUInt128; R: DWord): TUInt128;
    class operator  + (const L, R: TUInt128): TUInt128; inline;
    class operator  + (const L: TUInt128; R: DWord): TUInt128; inline;
    class operator  - (const L, R: TUInt128): TUInt128; inline;
    class operator  - (const L: TUInt128; R: DWord): TUInt128; inline;
    class operator  - (const L: TUInt128): TUInt128; inline;
    class operator  * (const L, R: TUInt128): TUInt128; inline;
    class operator  * (const L: TUInt128; R: DWord): TUInt128; inline;
    class operator  div(const aValue, aD: TUInt128): TUInt128;
    class operator  mod(const aValue, aD: TUInt128): TUInt128;
    class operator  div(const aValue: TUInt128; aD: DWord): TUInt128; inline;
    class operator  mod(const aValue: TUInt128; aD: DWord): DWord; inline;

    class function  MinValue: TUInt128; static;
    class function  MaxValue: TUInt128; static;
    class procedure DivRem(const aValue, aD: TUInt128; out aQ, aR: TUInt128); static;
    class function  DivRem(const aValue: TUInt128; aD: DWord; out aQ: TUInt128): DWord; static; inline;
    class function  Encode(aLo: QWord): TUInt128; static;
    class function  Encode(aLo, aHi: QWord): TUInt128; static;
    class function  Encode(v0, v1, v2, v3: DWord): TUInt128; static;
    class function  Random: TUInt128; static; inline;
    class function  RandomInRange(const aRange: TUInt128): TUInt128; static;
    class function  Parse(const s: string): TUInt128; static;
    class function  TryParse(const s: string; out aValue: TUInt128): Boolean; static;
    class function  Compare(const L, R: TUInt128): SizeInt; static; inline;
    class function  Equal(const L, R: TUInt128): Boolean; static; inline;
    class function  HashCode(const aValue: TUInt128): SizeInt; static; inline;
    function  Lo: QWord; inline;
    function  Hi: QWord; inline;
    function  IsZero: Boolean;
    procedure SetZero;
    procedure Negate; inline;
    function  IsOdd: Boolean; inline;
    function  IsTwoPower: Boolean; inline;
    function  PopCount: Integer;
    function  BitLength: Integer; inline;
    function  ToDouble: Double;
    function  ToExtended: Extended;
    function  ToString: string; inline;
    function  ToHexString(aMinDigits: Integer; aShowRadix: Boolean = False): string; inline;
    function  ToHexString(aShowRadix: Boolean = False): string; inline;
    property  Bits[aIndex: Integer]: Boolean read GetBit write SetBit;
    property  Bytes[aIndex: Integer]: Byte read GetByte write SetByte;
    property  DWords[aIndex: Integer]: DWord read GetDWord write SetDWord;
  end;

  PUInt128 = ^TUInt128;
  PInt128  = ^TInt128;

  { TInt128: signed-magnitude representation }
  TInt128 = record
  private
  type
    TLimb     = TUInt128.TLimb;
    TLimbs128 = TUInt128.TLimbs128;
    PLimb     = TUInt128.PLimb;
    TCompare  = TUInt128.TCompare;
  const
    SIGN_FLAG: TLimb = TLimb({$IFDEF USE_LIMB64}$8000000000000000{$ELSE}$80000000{$ENDIF});
    SIGN_MASK: TLimb = TLimb({$IFDEF USE_LIMB64}$7fffffffffffffff{$ELSE}$7fffffff{$ENDIF});
  var
    FLimbs: TLimbs128;
    function  GetBit(aIndex: Integer): Boolean;
    procedure SetBit(aIndex: Integer; aValue: Boolean);
    function  GetByte(aIndex: Integer): Byte;
    procedure SetByte(aIndex: Integer; aValue: Byte);
    function  GetDWord(aIndex: Integer): DWord;
    procedure SetDWord(aIndex: Integer; aValue: DWord);
    function  GetNormLimbs: TLimbs128; inline;
    class function  Cmp(const L, R: TInt128): TCompare; static;
    class function  Cmp(const L: TInt128; R: Integer): TCompare; static;
    class procedure DoAdd(a, b, s: PLimb); static;
    class procedure DoAddShort(a: PLimb; b: TLimb; s: PLimb); static;
    class function  DoSub(a, b, d: PLimb): TLimb; static;
    class function  DoSubShort(a: PLimb; b: TLimb; d: PLimb): TLimb; static;
    class procedure Add(const a, b: TInt128; out s: TInt128); static;
    class procedure AddShort(const a: TInt128; b: Integer; out s: TInt128); static;
    class procedure Sub(const a, b: TInt128; out d: TInt128); static;
    class procedure SubShort(const a: TInt128; b: Integer; out d: TInt128); static;
    class procedure DoMul(a, b, p: PInt128); static;
    class procedure DoMulShort(a: PInt128; b: Integer; p: PInt128); static;
    class procedure Divide(a, d, q, r: PInt128); static;
    class procedure DivQ(a, d, q: PInt128); static;
    class procedure DivR(a, d, r: PInt128); static;
    class function  DivShort(a: PInt128; d: Integer; q: PInt128): Integer; static;
    class procedure DivShortQ(a: PInt128; d: Integer; q: PInt128); static;
    class function  DivShortR(a: PInt128; d: Integer): Integer; static;
  public
    class operator  = (const L, R: TInt128): Boolean;
    class operator  <>(const L, R: TInt128): Boolean;
    class operator  > (const L, R: TInt128): Boolean; inline;
    class operator  >=(const L, R: TInt128): Boolean; inline;
    class operator  < (const L, R: TInt128): Boolean; inline;
    class operator  <=(const L, R: TInt128): Boolean; inline;

    class operator  = (const L: TInt128; R: Integer): Boolean; inline;
    class operator  <>(const L: TInt128; R: Integer): Boolean; inline;
    class operator  > (const L: TInt128; R: Integer): Boolean; inline;
    class operator  >=(const L: TInt128; R: Integer): Boolean; inline;
    class operator  < (const L: TInt128; R: Integer): Boolean; inline;
    class operator  <=(const L: TInt128; R: Integer): Boolean; inline;

    class operator  :=(const aValue: Integer): TInt128;
    class operator  :=(const aValue: TInt128): Double; inline;
    class operator  :=(const aValue: TInt128): string; inline;
    class operator  :=(const aValue: string): TInt128; inline;

    class operator  Inc(const aValue: TInt128): TInt128; inline;
    class operator  Dec(const aValue: TInt128): TInt128; inline;
    class operator  shl(const aValue: TInt128; aDist: Integer): TInt128;
    class operator  shr(const aValue: TInt128; aDist: Integer): TInt128;
    class operator  not(const aValue: TInt128): TInt128;
    class operator  and(const L, R: TInt128): TInt128;
    class operator  or (const L, R: TInt128): TInt128;
    class operator  xor(const L, R: TInt128): TInt128;
    class operator  + (const L, R: TInt128): TInt128; inline;
    class operator  + (const L: TInt128; R: Integer): TInt128; inline;
    class operator  - (const L, R: TInt128): TInt128; inline;
    class operator  - (const L: TInt128; R: Integer): TInt128; inline;
    class operator  - (const aValue: TInt128): TInt128;
    class operator  * (const L, R: TInt128): TInt128; inline;
    class operator  * (const L: TInt128; R: Integer): TInt128; inline;
    class operator  div(const aValue, aD: TInt128): TInt128; inline;
    class operator  mod(const aValue, aD: TInt128): TInt128; inline;
    class operator  div(const aValue: TInt128; aD: Integer): TInt128; inline;
    class operator  mod(const aValue: TInt128; aD: Integer): Integer; inline;

    class function  MinValue: TInt128; static; inline;
    class function  MaxValue: TInt128; static; inline;
    class procedure DivRem(const aValue, aD: TInt128; out aQ, aR: TInt128); static; inline;
    class function  DivRem(const aValue: TInt128; aD: Integer; out aQ: TInt128): Integer; static; inline;
    class function  Encode(aValue: Int64): TInt128; static;
    class function  Encode(aLo, aHi: QWord): TInt128; static; inline;
    class function  Encode(v0, v1, v2, v3: DWord): TInt128; static; inline;
    class function  Random: TInt128; static;
    class function  RandomInRange(const aRange: TInt128): TInt128; static;
    class function  Parse(const s: string): TInt128; static;
    class function  TryParse(const s: string; out aValue: TInt128): Boolean; static;
    class function  Compare(const L, R: TInt128): SizeInt; static; inline;
    class function  Equal(const L, R: TInt128): Boolean; static; inline;
    class function  HashCode(const aValue: TInt128): SizeInt; static; inline;
    function  Lo: QWord;
    function  Hi: QWord;
    function  IsZero: Boolean;
    procedure SetZero;
    function  IsOdd: Boolean; inline;
    function  IsNegative: Boolean; inline;
    function  IsPositive: Boolean; inline;
    function  Sign: TValueSign;
    procedure Negate; inline;
  { note: the BitLength of the negative value will always be 128 }
    function  BitLength: Integer; inline;
    function  AbsValue: TInt128;
    function  ToDouble: Double;
    function  ToExtended: Extended;
    function  ToString: string;
    function  ToHexString(aMinDigits: Integer; aShowRadix: Boolean = False): string; inline;
    function  ToHexString(aShowRadix: Boolean = False): string; inline;
    property  Bits[aIndex: Integer]: Boolean read GetBit write SetBit;
    property  Bytes[aIndex: Integer]: Byte read GetByte write SetByte;
    property  DWords[aIndex: Integer]: DWord read GetDWord write SetDWord;
  end;

implementation
uses
  LGHash;
{$B-}{$COPERATORS ON}{$POINTERMATH ON}{$MACRO ON}
{$IFDEF USE_LIMB64}
  {$DEFINE BsrLimb := BsrQWord}
  {$DEFINE BsfLimb := BsfQWord}
{$ELSE USE_LIMB64}
  {$DEFINE BsrLimb := BsrDWord}
  {$DEFINE BsfLimb := BsfDWord}
{$ENDIF USE_LIMB64}
{$IFDEF CPU_INTEL}
  {$ASMMODE INTEL}
{$ENDIF CPU_INTEL}

{ TUInt128 }

function TUInt128.GetBit(aIndex: Integer): Boolean;
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(BIT_PER_VALUE) then
    Result := FLimbs[aIndex shr LIMB_SIZE_LOG] and (TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK)) <> 0
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  Result := FLimbs[aIndex shr LIMB_SIZE_LOG] and (TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK)) <> 0;
{$ENDIF R+}
end;

procedure TUInt128.SetBit(aIndex: Integer; aValue: Boolean);
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(BIT_PER_VALUE) then
    if aValue then
      FLimbs[aIndex shr LIMB_SIZE_LOG] := FLimbs[aIndex shr LIMB_SIZE_LOG] or
                                          TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK)
    else
      FLimbs[aIndex shr LIMB_SIZE_LOG] := FLimbs[aIndex shr LIMB_SIZE_LOG] and
                                          not(TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK))
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  if aValue then
    FLimbs[aIndex shr LIMB_SIZE_LOG] := FLimbs[aIndex shr LIMB_SIZE_LOG] or
                                        TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK)
  else
    FLimbs[aIndex shr LIMB_SIZE_LOG] := FLimbs[aIndex shr LIMB_SIZE_LOG] and
                                        not(TLimb(1) shl (aIndex and LIMB_BITSIZE_MASK))
{$ENDIF R+}
end;

function TUInt128.GetByte(aIndex: Integer): Byte;
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(BYTE_PER_VALUE) then
    Result := PByte(@FLimbs)[aIndex]
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  Result := PByte(@FLimbs)[aIndex];
{$ENDIF R+}
end;

procedure TUInt128.SetByte(aIndex: Integer; aValue: Byte);
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(BYTE_PER_VALUE) then
    PByte(@FLimbs)[aIndex] := aValue
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  PByte(@FLimbs)[aIndex] := aValue;
{$ENDIF R+}
end;

function TUInt128.GetDWord(aIndex: Integer): DWord;
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(DWORD_PER_VALUE) then
    Result := PDWord(@FLimbs)[aIndex]
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  Result := PDWord(@FLimbs)[aIndex];
{$ENDIF R+}
end;

procedure TUInt128.SetDWord(aIndex: Integer; aValue: DWord);
begin
{$IFOPT R+}
  if SizeUInt(aIndex) < SizeUInt(DWORD_PER_VALUE) then
    PDWord(@FLimbs)[aIndex] := aValue
  else
    raise ERangeError.CreateFmt(SListIndexError, [aIndex]);
{$ELSE R+}
  PDWord(@FLimbs)[aIndex] := aValue;
{$ENDIF R+}
end;

class function TUInt128.Cmp(const a, b: TLimbs128): TCompare;
begin
{$IFDEF USE_LIMB64}
  if a[1] > b[1] then
    exit(1);
  if a[1] < b[1] then
    exit(-1);
  if a[0] > b[0] then
    exit(1);
  if a[0] < b[0] then
    exit(-1);
{$ELSE USE_LIMB64}
  if a[3] > b[3] then
    exit(1);
  if a[3] < b[3] then
    exit(-1);
  if a[2] > b[2] then
    exit(1);
  if a[2] < b[2] then
    exit(-1);
  if a[1] > b[1] then
    exit(1);
  if a[1] < b[1] then
    exit(-1);
  if a[0] > b[0] then
    exit(1);
  if a[0] < b[0] then
    exit(-1);
{$ENDIF USE_LIMB64}
  Result := 0;
end;

class function TUInt128.MsBitIndex(const aValue: TLimbs128): Integer;
begin
{$IFDEF USE_LIMB64}
 if aValue[1] <> 0 then
   exit(Integer(BsrLimb(aValue[1])) + BIT_PER_LIMB);
 if aValue[0] <> 0 then
   exit(Integer(BsrLimb(aValue[0])));
{$ELSE USE_LIMB64}
  if aValue[3] <> 0 then
    exit(Integer(BsrLimb(aValue[3])) + BIT_PER_LIMB * 3);
  if aValue[2] <> 0 then
    exit(Integer(BsrLimb(aValue[2])) + BIT_PER_LIMB * 2);
  if aValue[1] <> 0 then
    exit(Integer(BsrLimb(aValue[1])) + BIT_PER_LIMB);
  if aValue[0] <> 0 then
    exit(Integer(BsrLimb(aValue[0])));
{$ENDIF USE_LIMB64}
  Result := -1;
end;

class function TUInt128.MsLimbIndex(const aValue: TLimbs128): Integer;
begin
{$IFDEF USE_LIMB64}
 if aValue[1] <> 0 then
   exit(1);
 if aValue[0] <> 0 then
   exit(0);
{$ELSE USE_LIMB64}
  if aValue[3] <> 0 then
    exit(3);
  if aValue[2] <> 0 then
    exit(2);
  if aValue[1] <> 0 then
    exit(1);
  if aValue[0] <> 0 then
    exit(0);
{$ENDIF USE_LIMB64}
  Result := -1;
end;

class function TUInt128.NlzLimb(aValue: TLimb): Integer;
begin
  Result := Pred(BIT_PER_LIMB - BsrLimb(aValue));
end;

class procedure TUInt128.SetSingleLimb(aLimb: TLimb; out aValue: TLimbs128);
begin
{$IFDEF USE_LIMB64}
  aValue[0] := aLimb;
  aValue[1] := 0;
{$ELSE USE_LIMB64}
  aValue[0] := aLimb;
  aValue[1] := 0;
  aValue[2] := 0;
  aValue[3] := 0;
{$ENDIF USE_LIMB64}
end;

{$PUSH}{$Q-}{$R-}
class procedure TUInt128.DoNeg(a: PLimb; n: PLimb);
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
  xor  r8, r8
{$IFDEF MSWINDOWS}  //a in rcx, n in rdx
  sub  rax, qword ptr[rcx]
  sbb  r8, qword ptr[rcx+8]
  mov  qword ptr[rdx], rax
  mov  qword ptr[rdx+8], r8
{$ELSE MSWINDOWS}   //a in rdi, n in rsi,
  sub  rax, qword ptr[rdi]
  sbb  r8, qword ptr[rdi+8]
  mov  qword ptr[rsi], rax
  mov  qword ptr[rsi+8], r8
{$ENDIF MSWINDOWS}
end;
  {$ELSE CPUX64}
asm
  sub  esp, 16         //a in eax, n in edx,
  mov  [esp], ebx
  mov  [esp+4], esi
  mov  [esp+8], edi

  xor  ecx, ecx
  xor  ebx, ebx
  xor  esi, esi
  xor  edi, edi

  sub  ecx, [eax]
  sbb  ebx, [eax+4]
  sbb  esi, [eax+8]
  sbb  edi, [eax+12]

  mov  [edx], ecx
  mov  [edx+4], ebx
  mov  [edx+8], esi
  mov  [edx+12], edi

  mov  ebx, [esp]
  mov  esi, [esp+4]
  mov  edi, [esp+8]
  add  esp, 16
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v, brw: TLimb;
begin
  brw := TLimb(a[0] <> 0);
  n[0] := -a[0];

  v := -a[1];
  n[1] := v - brw;
  brw := TLimb(n[1] > v) or TLimb(v <> 0);

  v := -a[2];
  n[2] := v - brw;
  brw := TLimb(n[1] > v) or TLimb(v <> 0);

  n[3] := -a[3] - brw;
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoAdd(a, b, s: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, s in r8
  mov  r9, qword ptr[rcx]
  add  r9, qword ptr[rdx]
  mov  qword ptr[r8], r9      //0

  mov  r9, qword ptr[rcx+8]
  adc  r9, qword ptr[rdx+8]
  mov  qword ptr[r8+8], r9    //1
{$ELSE MSWINDOWS}    //a in rdi, b in rsi, s in rdx
  mov  rcx, qword ptr[rdi]
  add  rcx, qword ptr[rsi]
  mov  qword ptr[rdx], rcx    //0

  mov  rcx, qword ptr[rdi+8]
  adc  rcx, qword ptr[rsi+8]
  mov  qword ptr[rdx+8], rcx  //1
{$ENDIF MSWINDOWS}
  setc al
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8
  mov  [esp], ebx    //a in eax, b in edx, s in ecx

  mov  ebx, [eax]
  add  ebx, [edx]
  mov  [ecx], ebx    //0

  mov  ebx, [eax+4]
  adc  ebx, [edx+4]
  mov  [ecx+4], ebx  //1

  mov  ebx, [eax+8]
  adc  ebx, [edx+8]
  mov  [ecx+8], ebx  //2

  mov  ebx, [eax+12]
  mov  eax, 0
  adc  ebx, [edx+12]
  setc al
  mov  [ecx+12], ebx //3

  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v, c: TLimb;
begin
  s[0] := a[0] + b[0];
  c := TLimb(s[0] < a[0]);

  v := c + a[1];
  c := TLimb(v < c);
  s[1] := v + b[1];
  c += TLimb(s[1] < v);


  v := c + a[2];
  c := TLimb(v < c);
  s[2] := v + b[2];
  c += TLimb(s[2] < v);

  v := c + a[3];
  c := TLimb(v < c);
  s[3] := v + b[3];

  Result := c + TLimb(s[3] < v);
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoAddShort(a: PLimb; b: TLimb; s: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
{$IFDEF MSWINDOWS} //a in rcx, b in rdx, s in r8
  add  rdx, qword ptr[rcx]
  mov  qword ptr[r8], rdx

  mov  rdx, qword ptr[rcx+8]
  adc  rdx, 0
  mov  qword ptr[r8+8], rdx
{$ELSE MSWINDOWS}  //a in rdi, b in rsi, s in rdx
  add  rsi, qword ptr[rdi]
  mov  qword ptr[rdx], rsi

  mov  rsi, qword ptr[rdi+8]
  adc  rsi, 0
  mov  qword ptr[rdx+8], rsi
{$ENDIF MSWINDOWS}
  setc al
end;
  {$ELSE CPUX64}
asm  //a in eax, b in edx, s in ecx
  add  edx, [eax]
  mov  [ecx], edx

  mov  edx, [eax+4]
  adc  edx, 0
  mov  [ecx+4], edx

  mov  edx, [eax+8]
  adc  edx, 0
  mov  [ecx+8], edx

  mov  edx, [eax+12]
  mov  eax, 0
  adc  edx, 0
  mov  [ecx+12], edx

  setc al
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
begin
  s[0] := b + a[0];
  b := TLimb(s[0] < b);

  s[1] := b + a[1];
  b := TLimb(s[1] < b);

  s[2] := b + a[2];
  b := TLimb(s[2] < b);

  s[3] := b + a[3];
  Result := TLimb(s[3] < b);
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoSub(a, b, d: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, d in r8
  mov  r9, qword ptr[rcx]
  sub  r9, qword ptr[rdx]
  mov  qword ptr[r8], r9     //0

  mov  r9, qword ptr[rcx+8]
  sbb  r9, qword ptr[rdx+8]
  mov  qword ptr[r8+8], r9   //1
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, d in rdx
  mov  rcx, qword ptr[rdi]
  sub  rcx, qword ptr[rsi]
  mov  qword ptr[rdx], rcx   //0

  mov  rcx, qword ptr[rdi+8]
  sbb  rcx, qword ptr[rsi+8]
  mov  qword ptr[rdx+8], rcx //3
{$ENDIF MSWINDOWS}
  setc al
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8
  mov  [esp], ebx    //a in eax, b in edx, d in ecx

  mov  ebx, [eax]
  sub  ebx, [edx]
  mov  [ecx], ebx    //0

  mov  ebx, [eax+4]
  sbb  ebx, [edx+4]
  mov  [ecx+4], ebx  //1

  mov  ebx, [eax+8]
  sbb  ebx, [edx+8]
  mov  [ecx+8], ebx  //2

  mov  ebx, [eax+12]
  mov  eax, 0
  sbb  ebx, [edx+12]
  mov  [ecx+12], ebx //3
  setc al

  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v, brw: TLimb;
begin
  v := a[0] - b[0];
  brw := TLimb(v > a[0]);
  d[0] := v;

  v := a[1] - brw;
  brw := TLimb(v > a[1]);
  d[1] := v - b[1];
  brw += TLimb(d[1] > v);

  v := a[2] - brw;
  brw := TLimb(v > a[2]);
  d[2] := v - b[2];
  brw += TLimb(d[2] > v);

  v := a[3] - brw;
  brw := TLimb(v > a[3]);
  d[3] := v - b[3];
  Result := brw + TLimb(d[3] > v);
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoSubShort(a: PLimb; b: TLimb; d: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, d in r8
  mov  r9, qword ptr[rcx]
  sub  r9, rdx
  mov  qword ptr[r8], r9     //0

  mov  r9, qword ptr[rcx+8]
  sbb  r9, 0
  mov  qword ptr[r8+8], r9   //1
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, d in rdx
  mov  rcx, qword ptr[rdi]
  sub  rcx, rsi
  mov  qword ptr[rdx], rcx   //0

  mov  rcx, qword ptr[rdi+8]
  sbb  rcx, 0
  mov  qword ptr[rdx+8], rcx //1
{$ENDIF MSWINDOWS}
  setc al
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8         //a in eax, b in edx, d in ecx
  mov  [esp], ebx

  mov  ebx, [eax]
  sub  ebx, edx
  mov  [ecx], ebx     //0

  mov  ebx, [eax+4]
  sbb  ebx, 0
  mov  [ecx+4], ebx   //1

  mov  ebx, [eax+8]
  sbb  ebx, 0
  mov  [ecx+8], ebx   //2

  mov  ebx, [eax+12]
  mov  eax, 0
  sbb  ebx, 0
  mov  [ecx+12], ebx  //3
  setc al

  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  brw: TLimb;
begin
  brw := a[0];
  d[0] := brw - b;
  brw := TLimb(d[0] > brw);

  b := a[1];
  d[1] := b - brw;
  brw := TLimb(d[1] > b);

  b := a[2];
  d[2] := b - brw;
  brw := TLimb(d[2] > b);

  b := a[3];
  d[3] := b - brw;
  Result := TLimb(d[3] > b);
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoMul(a, b, p: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
{$IFOPT Q+}
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, p in r8
  sub   rsp, 16
  mov   qword ptr[rsp], rsi
  mov   qword ptr[rsp+8], rdi

  mov   rdi, rcx    //rdi <- a
  mov   rsi, rdx    //rsi <- b
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, p in rdx
  mov   r8, rdx     //r8  <- p
{$ENDIF MSWINDOWS}
  mov   rcx, qword ptr[rsi]

  mov   rax, qword ptr[rdi]
  mul   rcx
  mov   qword ptr[r8], rax
  mov   r9, rdx

  mov   rax, qword ptr[rdi+8]
  mul   rcx
  add   rax, r9
  adc   rdx, 0
  mov   qword ptr[r8+8], rax
  xor   r9, r9
  test  rdx, rdx
  setnz r9b
/////////////////////////
  mov   rax, qword ptr[rdi]
  mul   qword ptr[rsi+8]
  add   qword ptr[r8+8], rax
  adc   rdx, 0
  xor   rax, rax
  test  rdx, rdx
  setnz al
  add   rax, r9

{$IFDEF MSWINDOWS}
  mov  rsi, qword ptr[rsp]
  mov  rdi, qword ptr[rsp+8]
  add  rsp, 16
{$ENDIF}
{$ELSE Q+}
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, p in r8
  sub   rsp, 16
  mov   qword ptr[rsp], rsi
  mov   qword ptr[rsp+8], rdi

  mov   rdi, rcx    //rdi <- a
  mov   rsi, rdx    //rsi <- b
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, p in rdx
  mov   r8, rdx     //r8  <- p
{$ENDIF MSWINDOWS}
  mov   rcx, qword ptr[rsi]

  mov   rax, qword ptr[rdi]
  mul   rcx
  mov   qword ptr[r8], rax
  mov   r9, rdx

  mov   rax, qword ptr[rdi+8]
  mul   rcx
  add   rax, r9
  mov   qword ptr[r8+8], rax
/////////////////////////
  mov   rax, qword ptr[rdi]
  mul   qword ptr[rsi+8]
  add   qword ptr[r8+8], rax

  xor   rax, rax
{$IFDEF MSWINDOWS}
  mov  rsi, qword ptr[rsp]
  mov  rdi, qword ptr[rsp+8]
  add  rsp, 16
{$ENDIF}
{$ENDIF Q+}
end;
  {$ELSE CPUX64}
asm
{$IFOPT Q+}
  sub   esp, 24
  mov   [esp   ], ebp
  mov   [esp+ 4], ebx
  mov   [esp+ 8], esi
  mov   [esp+12], edi
/////////////////////////////////
  mov   esi, eax                  // esi <- a
  mov   edi, ecx                  // edi <- p
  mov   ecx, edx                  // ecx <- b
/////////////////////////////////// mul by b[0]
  mov   ebp, [ecx]

  mov   eax, [esi]
  mul   ebp
  mov   [edi], eax
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  mov   [edi+4], eax
  mov   ebx, edx      //1

  mov   eax, [esi+8]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  mov   [edi+8], eax
  mov   ebx, edx      //2

  mov   eax, [esi+12]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  mov   [edi+12], eax //3
  xor   ebx, ebx
  test  edx, edx
  setnz bl
  mov   [esp+16], ebx
/////////////////////////////////  mul by b[1]
  mov   ebp, [ecx+4]

  mov   eax, [esi]
  mul   ebp
  add   [edi+4], eax
  adc   edx, 0
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  add   [edi+8], eax
  adc   edx, 0
  mov   ebx, edx      //1

  mov   eax, [esi+8]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  add   [edi+12], eax
  adc   edx, 0
  xor   ebx, ebx      //2
  test  edx, edx
  setnz bl
  add   [esp+16], ebx
/////////////////////////////////  mul by b[2]
  mov   ebp, [ecx+8]

  mov   eax, [esi]
  mul   ebp
  add   [edi+8], eax
  adc   edx, 0
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  add   [edi+12], eax
  adc   edx, 0
  xor   ebx, ebx      //1
  test  edx, edx
  setnz bl
  add   [esp+16], ebx
/////////////////////////////////  mul by b[3]
  mov   eax, [esi]
  mul   [ecx+12]
  add   [edi+12], eax
  adc   edx, 0
  xor   eax, eax
  test  edx, edx
  setnz al
  add   eax, [esp+16]
///////////////////////////////// epilog
  mov  ebp, [esp   ]
  mov  ebx, [esp+ 4]
  mov  esi, [esp+ 8]
  mov  edi, [esp+12]
  add  esp, 24
{$ELSE Q+}  ///////////////////
  sub   esp, 16
  mov   [esp   ], ebp
  mov   [esp+ 4], ebx
  mov   [esp+ 8], esi
  mov   [esp+12], edi
/////////////////////////////////
  mov   esi, eax                  // esi <- a
  mov   edi, ecx                  // edi <- p
  mov   ecx, edx                  // ecx <- b
/////////////////////////////////// mul by b[0]
  mov   ebp, [ecx]

  mov   eax, [esi]
  mul   ebp
  mov   [edi], eax
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  mov   [edi+4], eax
  mov   ebx, edx      //1

  mov   eax, [esi+8]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  mov   [edi+8], eax
  mov   ebx, edx      //2

  mov   eax, [esi+12]
  mul   ebp
  add   eax, ebx
  mov   [edi+12], eax //3
/////////////////////////////////  mul by b[1]
  mov   ebp, [ecx+4]

  mov   eax, [esi]
  mul   ebp
  add   [edi+4], eax
  adc   edx, 0
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  adc   edx, 0
  add   [edi+8], eax
  adc   edx, 0
  mov   ebx, edx      //1

  mov   eax, [esi+8]
  mul   ebp
  add   eax, ebx
  add   [edi+12], eax //2
/////////////////////////////////  mul by b[2]
  mov   ebp, [ecx+8]

  mov   eax, [esi]
  mul   ebp
  add   [edi+8], eax
  adc   edx, 0
  mov   ebx, edx      //0

  mov   eax, [esi+4]
  mul   ebp
  add   eax, ebx
  add   [edi+12], eax //1
/////////////////////////////////  mul by b[3]
  mov   eax, [esi]
  mul   [ecx+12]
  add   [edi+12], eax

  xor  eax, eax
///////////////////////////////// epilog
  mov  ebp, [esp   ]
  mov  ebx, [esp+ 4]
  mov  esi, [esp+ 8]
  mov  edi, [esp+12]
  add  esp, 16
{$ENDIF Q+}
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  Prod: QWord;
  Digs: array[0..1] of TLimb absolute Prod;
begin
  Prod := QWord(a[0]) * QWord(b[0]);
  p[0] := Digs[0];
  Prod := QWord(a[1]) * QWord(b[0]) + QWord(Digs[1]);
  p[1] := Digs[0];
  Prod := QWord(a[2]) * QWord(b[0]) + QWord(Digs[1]);
  p[2] := Digs[0];
  Prod := QWord(a[3]) * QWord(b[0]) + QWord(Digs[1]);
  p[3] := Digs[0];
{$IFOPT Q+}
  Result := Ord(Digs[1] <> 0);
{$ENDIF Q+}

  Prod := QWord(a[0]) * QWord(b[1]) + QWord(p[1]);
  p[1] := Digs[0];
  Prod := QWord(a[1]) * QWord(b[1]) + QWord(p[2]) + QWord(Digs[1]);
  p[2] := Digs[0];
  Prod := QWord(a[3]) * QWord(b[1]) + QWord(p[3]) + QWord(Digs[1]);
  p[3] := Digs[0];
{$IFOPT Q+}
  Result += Ord(Digs[1] <> 0);
{$ENDIF Q+}

  Prod := QWord(a[0]) * QWord(b[2]) + QWord(p[2]);
  p[2] := Digs[0];
  Prod := QWord(a[1]) * QWord(b[2]) + QWord(p[3]) + QWord(Digs[1]);
  p[3] := Digs[0];
{$IFOPT Q+}
  Result += Ord(Digs[1] <> 0);
{$ENDIF Q+}

  Prod := QWord(a[0]) * QWord(b[3]) + QWord(p[3]);
  p[3] := Digs[0];
{$IFOPT Q+}
  Result += Ord(Digs[1] <> 0);
{$ELSE Q+}
  Result := 0;
{$ENDIF Q+}
end;
{$ENDIF CPU_INTEL}

class function TUInt128.DoMulShort(a: PLimb; b: TLimb; p: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
{$IFDEF MSWINDOWS} //a in rcx, b in rdx, p in r8
  mov  r9, rdx     // r9  <- b

  mov  rax, qword ptr[rcx]
  mul  r9
  mov  qword ptr[r8], rax
  mov  r10, rdx

  mov  rax, qword ptr[rcx+8]
  mul  r9
  add  rax, r10
  adc  rdx, 0
  mov  qword ptr[r8+8], rax

  mov  rax, rdx
{$ELSE MSWINDOWS} // a in rdi, b in rsi, p in rdx
  mov  r8, rdx    // r8 <- p

  mov  rax, qword ptr[rdi]
  mul  rsi
  mov  qword ptr[r8], rax
  mov  r9, rdx

  mov  rax, qword ptr[rdi+8]
  mul  rsi
  add  rax, r9
  adc  rdx, 0
  mov  qword ptr[r8+8], rax

  mov  rax, rdx
{$ENDIF MSWINDOWS}
end;
  {$ELSE CPUX64}
asm
  sub  esp, 16
  mov  [esp  ], ebx
  mov  [esp+4], esi
  mov  [esp+8], edi

  mov  esi, eax            //esi <- a
  mov  ebx, edx            //ebx <- b
                           //p in ecx
  mov  eax, [esi]
  mul  ebx
  mov  [ecx], eax

  mov  eax, [esi+4]
  mov  edi, edx            //0
  mul  ebx
  add  eax, edi
  adc  edx, 0
  mov  [ecx+4], eax
  mov  edi, edx            //1

  mov  eax, [esi+8]
  mul  ebx
  add  eax, edi
  adc  edx, 0
  mov  [ecx+8], eax
  mov  edi, edx            //2

  mov  eax, [esi+12]
  mul  ebx
  add  eax, edi
  adc  edx, 0
  mov  [ecx+12], eax       //3

  mov  eax, edx

  mov  ebx, [esp  ]
  mov  esi, [esp+4]
  mov  edi, [esp+8]
  add  esp, 16
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  Prod: QWord;
  Digs: array[0..1] of TLimb absolute Prod;
begin
  Prod := QWord(a[0]) * QWord(b);
  p[0] := Digs[0];

  Prod := QWord(a[1]) * QWord(b) + QWord(Digs[1]);
  p[1] := Digs[0];

  Prod := QWord(a[2]) * QWord(b) + QWord(Digs[1]);
  p[2] := Digs[0];

  Prod := QWord(a[3]) * QWord(b) + QWord(Digs[1]);
  p[3] := Digs[0];
  Result := Digs[1];
end;
{$ENDIF CPU_INTEL}

class function TUInt128.ShortBitShiftLeft(a, r: PLimb; aDist: Integer): TLimb;
begin
  if aDist = 0 then
    begin
      PUInt128(r)^ := PUInt128(a)^;
      exit(0);
    end;
{$IFDEF USE_LIMB64}
  r[0] := a[0] shl aDist;
  r[1] := a[1] shl aDist or a[0] shr (BIT_PER_LIMB - aDist);
  Result := a[1] shr (BIT_PER_LIMB - aDist);
{$ELSE USE_LIMB64}
  r[0] := a[0] shl aDist;
  r[1] := a[1] shl aDist or a[0] shr (BIT_PER_LIMB - aDist);
  r[2] := a[2] shl aDist or a[1] shr (BIT_PER_LIMB - aDist);
  r[3] := a[3] shl aDist or a[2] shr (BIT_PER_LIMB - aDist);
  Result := a[3] shr (BIT_PER_LIMB - aDist);
{$ENDIF USE_LIMB64}
end;

class procedure TUInt128.ShortBitShiftRight(a, r: PLimb; aDist: Integer);
begin
  if aDist = 0 then
    begin
      PUInt128(r)^ := PUInt128(a)^;
      exit;
    end;
{$IFDEF USE_LIMB64}
  r[1] := a[1] shr aDist;
  r[0] := a[0] shr aDist or a[1] shl (BIT_PER_LIMB - aDist);
{$ELSE USE_LIMB64}
  r[3] := a[3] shr aDist;
  r[2] := a[2] shr aDist or a[3] shl (BIT_PER_LIMB - aDist);
  r[1] := a[1] shr aDist or a[2] shl (BIT_PER_LIMB - aDist);
  r[0] := a[0] shr aDist or a[1] shl (BIT_PER_LIMB - aDist);
{$ENDIF USE_LIMB64}
end;

class procedure TUInt128.BitShiftLeft(a, r: PLimb; aDist: Integer);
var
  BitDist: Integer;
begin
  BitDist := aDist and LIMB_BITSIZE_MASK;
  aDist := aDist shr LIMB_SIZE_LOG;
{$IFDEF USE_LIMB64}
  case aDist of
    0:
      begin
        r[0] := a[0] shl BitDist;
        r[1] := a[1] shl BitDist or a[0] shr (BIT_PER_LIMB - BitDist);
      end;
    1:
      if BitDist <> 0 then
        begin
          r[0] := 0;
          r[1] := a[0] shl BitDist;
        end
      else
        begin
          r[0] := 0;
          r[1] := a[0];
        end;
  end;
{$ELSE USE_LIMB64}
  case aDist of
    0:
      begin
        r[0] := a[0] shl BitDist;
        r[1] := a[1] shl BitDist or a[0] shr (BIT_PER_LIMB - BitDist);
        r[2] := a[2] shl BitDist or a[1] shr (BIT_PER_LIMB - BitDist);
        r[3] := a[3] shl BitDist or a[2] shr (BIT_PER_LIMB - BitDist);
      end;
    1:
      if BitDist <> 0 then
        begin
          r[0] := 0;
          r[1] := a[0] shl BitDist;
          r[2] := a[1] shl BitDist or a[0] shr (BIT_PER_LIMB - BitDist);
          r[3] := a[2] shl BitDist or a[1] shr (BIT_PER_LIMB - BitDist);
        end
      else
        begin
          r[0] := 0;
          r[1] := a[0];
          r[2] := a[1];
          r[3] := a[2];
        end;
    2:
      if BitDist <> 0 then
        begin
          r[0] := 0;
          r[1] := 0;
          r[2] := a[0] shl BitDist;
          r[3] := a[1] shl BitDist or a[0] shr (BIT_PER_LIMB - BitDist);
        end
      else
        begin
          r[0] := 0;
          r[1] := 0;
          r[2] := a[0];
          r[3] := a[1];
        end;
    3:
      if BitDist <> 0 then
        begin
          r[0] := 0;
          r[1] := 0;
          r[2] := 0;
          r[3] := a[0] shl BitDist;
        end
      else
        begin
          r[0] := 0;
          r[1] := 0;
          r[2] := 0;
          r[3] := a[0];
        end
  end;
{$ENDIF USE_LIMB64}
end;

class procedure TUInt128.BitShiftRight(a, r: PLimb; aDist: Integer);
var
  BitDist: Integer;
begin
  BitDist := aDist and LIMB_BITSIZE_MASK;
  aDist := aDist shr LIMB_SIZE_LOG;
{$IFDEF USE_LIMB64}
  case aDist of
    0:
      begin
        r[1] := a[1] shr BitDist;
        r[0] := a[0] shr BitDist or a[1] shl (BIT_PER_LIMB - BitDist);
      end;
    1:
      if BitDist <> 0 then
        begin
          r[1] := 0;
          r[0] := a[1] shr BitDist;
        end
      else
        begin
          r[0] := a[1];
          r[1] := 0;
        end;
  end;
{$ELSE USE_LIMB64}
  case aDist of
    0:
      begin
        r[3] := a[3] shr BitDist;
        r[2] := a[2] shr BitDist or a[3] shl (BIT_PER_LIMB - BitDist);
        r[1] := a[1] shr BitDist or a[2] shl (BIT_PER_LIMB - BitDist);
        r[0] := a[0] shr BitDist or a[1] shl (BIT_PER_LIMB - BitDist);
      end;
    1:
      if BitDist <> 0 then
        begin
          r[3] := 0;
          r[2] := a[3] shr BitDist;
          r[1] := a[2] shr BitDist or a[3] shl (BIT_PER_LIMB - BitDist);
          r[0] := a[1] shr BitDist or a[2] shl (BIT_PER_LIMB - BitDist);
        end
      else
        begin
          r[0] := a[1];
          r[1] := a[2];
          r[2] := a[3];
          r[3] := 0;
        end;
    2:
      if BitDist <> 0 then
        begin
          r[3] := 0;
          r[2] := 0;
          r[1] := a[3] shr BitDist;
          r[0] := a[2] shr BitDist or a[3] shl (BIT_PER_LIMB - BitDist);
        end
      else
        begin
          r[0] := a[2];
          r[1] := a[3];
          r[2] := 0;
          r[3] := 0;
        end;
    3:
      if BitDist <> 0 then
        begin
          r[3] := 0;
          r[2] := 0;
          r[1] := 0;
          r[0] := a[3] shr BitDist;
        end
      else
        begin
          r[0] := a[3];
          r[1] := 0;
          r[2] := 0;
          r[3] := 0;
        end;
  end;
{$ENDIF USE_LIMB64}
end;

class procedure TUInt128.DoDiv(r, d, q: PLimb);
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  sub  rsp, 64
  mov  qword ptr[rsp   ], rbx
  mov  qword ptr[rsp +8], r12
  mov  qword ptr[rsp+16], r13
  mov  qword ptr[rsp+24], r14
  mov  qword ptr[rsp+32], r15
{$IFDEF MSWINDOWS}         //r in rcx, d in rdx, q in r8
  mov  qword ptr[rsp+40], rsi
  mov  qword ptr[rsp+48], rdi
  mov  rsi, rdx  //rsi <- d
  mov  rdi, rcx  //rdi <- r
  mov  rbx, r8   //rbx <- q
{$ELSE}                    //r in rdi, d in rsi, q in rdx
  mov  rbx, rdx  //rbx <- q
{$ENDIF}
  ////////////////////////////////////
  mov  rax, qword ptr[rdi+16]
  mov  r8,  LIMB_PER_VALUE
  or   rax, rax
  lea  rdx, [rdi+8]
  jnz  @doneRcount

@checkRcount:
  mov  rax, qword ptr[rdx]
  or   rax, rax
  jnz  @doneRcount
  dec  r8
  lea  rdx, [rdx-8]
  jnz  @checkRcount

@doneRcount:
  mov  rcx, r8                      // rcx <= rCount

  lea  rdx, [rsi+8]
  mov  r9, qword ptr[rbx]           // r9  <= dCount
  sub  rcx, r9                      // rcx <= qCount

  mov  r10, qword ptr[rsi+r9*8-8]   // r10 <= dMSLimb
  mov  r11, qword ptr[rsi+r9*8-16]  // r11 <= dNextLimb

@MainLoop:
  //estimation
  lea  r12, [rcx+r9]                //I + dCount
  mov  rdx, qword ptr[rdi+r12*8]    //rdx <= r[I + dCount]
  mov  r15, qword ptr[rdi+r12*8-16] //r15 <= r[I + dCount - 2]
  cmp  rdx, r10
  jae  @DTooLarge
  mov  rax, qword ptr[rdi+r12*8-8]  //rax <= r[I + dCount - 1]
  div  r10
  mov  r13, rax                     //r13 <= QHat
  mov  r14, rdx                     //r14 <= RHat
  jmp  @RefineEstimate

@DTooLarge:
  mov  r13, MAX_LIMB
  mov  rax, rdx
  xor  rdx, rdx
  div  r10
  mov  rax, qword ptr[rdi+r12*8]
  div  r10
  mov  rax, rdx
  add  rax, r10
  jc   @MulAndSub
  mov  r14, rax

@RefineEstimate:
  mov  rax, r11
  mul  r13
  cmp  rdx, r14
  ja   @DecQhat
  jb   @MulAndSub
  cmp  rax, r15
  jbe  @MulAndSub

@DecQhat:
  dec  r13
  add  r14, r10
  jc   @MulAndSub
  jmp  @RefineEstimate

@MulAndSub:
  lea  r12, [rdi+rcx*8]               //r[I]
  mov  r8, r9
  xor  r15, r15
  mov  r14, rsi                       //d

@MulAndSubLoop:
  mov  rax, qword ptr[r14]
  mul  r13
  lea  r12, [r12+8]
  lea  r14, [r14+8]
  add  rax, r15
  adc  rdx, 0
  sub  qword ptr[r12-8], rax
  adc  rdx, 0
  dec  r8
  mov  r15, rdx
  jnz  @MulAndSubLoop

  sub  qword ptr[r12], r15
  jnc  @RightQhat

  //compensating addition
  dec  r13                    // todo: more tests needed !!!

  lea  r12, [rdi+rcx*8]
  mov  r14, rsi
  xor  r15, r15
  mov  rdx, r9
@CmpAddLoop:
  mov  rax, qword ptr[r14]
  add  rax, r15
  mov  r15, 0
  adc  r15, 0
  add  qword ptr[r12], rax
  adc  r15, 0
  dec  rdx
  lea  r14, [r14+8]
  lea  r12, [r12+8]
  jnz  @CmpAddLoop

  add  qword ptr[r12], r15

@RightQhat:
  dec  rcx
  mov  [rbx+rcx*8+8], r13
  jge  @MainLoop
  //jnz  @MainLoop
  ///////////////////////////////////////
@done:
  ///////////////////////////////////////
  mov  rbx, qword ptr[rsp   ]
  mov  r12, qword ptr[rsp +8]
  mov  r13, qword ptr[rsp+16]
  mov  r14, qword ptr[rsp+24]
  mov  r15, qword ptr[rsp+32]
{$IFDEF MSWINDOWS}
  mov  rsi, qword ptr[rsp+40]
  mov  rdi, qword ptr[rsp+48]
{$ENDIF}
  add  rsp, 64
end;
  {$ELSE CPUX64}
asm
  sub  esp, 64

  mov  [esp   ], ebp
  mov  [esp+ 4], ebx
  mov  [esp+ 8], esi
  mov  [esp+12], edi
  /////////////////////////////////
  mov  ebx, eax                  // ebx <= r

  mov  esi, edx                  // esi <= d
  mov  edi, ecx                  // edi <= q
  mov  [esp+16], eax             // [esp+16] <= r
  mov  [esp+20], edx             // [esp+20] <= d
  mov  [esp+24], ecx             // [esp+24] <= q

  mov  eax, [ebx+16]
  mov  ecx, LIMB_PER_VALUE
  or   eax, eax
  lea  ebx, [ebx+12]
  jnz  @doneRcount

@checkRcount:
  mov  eax, [ebx]
  or   eax, eax
  jnz  @doneRcount
  dec  ecx
  lea  ebx, [ebx-4]
  jnz  @checkRcount

@doneRcount:
  mov  [esp+28], ecx             // [esp+28] <= rCount
  mov  ebp, ecx                  // ebp <= rCount

  mov  ecx, [edi]                // ecx <= dCount
  sub  ebp, [edi]
  mov  [esp+32], ecx             // [esp+32] <= dCount

  mov  eax, [esi+ecx*4-4]
  mov  edx, [esi+ecx*4-8]
  mov  [esp+36], eax             // [esp+36] <= dMSLimb
  mov  [esp+40], edx             // [esp+40] <= dNextLimb

  mov  ecx, ebp                  // ecx <= rCount - dCount
  mov  ebx, [esp+16]             // ebx <= @R

@mainloop:
  //estimation
  mov  edi, [esp+32]             // edi <= dCount
  add  edi, ecx
  mov  edx, [ebx+edi*4]          // edx <= R[I + dCount]
  mov  ebp, [ebx+edi*4-8]        // ebp <= R[I + dCount - 2]
  cmp  edx, [esp+36]
  jae  @DTooLarge
  mov  eax, [ebx+edi*4-4]        // eax <= R[I + dCount - 1]
  div  [esp+36]
  mov  esi, eax                  // esi <= QHat
  mov  [esp+56], edx             // [esp+56] <= RHat
  jmp  @RefineEstimation

@DTooLarge:
  mov  esi, MAX_LIMB
  mov  eax, edx
  xor  edx, edx
  div  [esp+36]
  mov  eax, [ebx+edi*4]
  div  [esp+36]
  mov  eax, edx
  add  eax, [esp+36]
  jc   @MultAndSub
  mov  [esp+56], eax

@RefineEstimation:
  mov  eax, [esp+40]
  mul  esi
  cmp  edx, [esp+56]
  ja   @DecQhat
  jb   @MultAndSub
  cmp  eax, ebp
  jbe  @MultAndSub

@DecQhat:
  dec  esi
  mov  eax, [esp+56]
  add  eax, [esp+36]
  mov  [esp+56], eax
  jc   @MultAndSub
  jmp  @RefineEstimation

@MultAndSub:
  lea  ebx, [ebx+ecx*4]
  xor  ebp, ebp
  mov  [esp+60], ecx
  mov  ecx, [esp+32]            // ecx <= dCount
  mov  edi, [esp+20]            // edi <= d

@MulAndSubLoop:
  mov  eax, [edi]
  mul  esi
  lea  edi, [edi+4]
  lea  ebx, [ebx+4]
  add  eax, ebp
  adc  edx, 0
  sub  [ebx-4], eax
  adc  edx, 0
  dec  ecx
  mov  ebp, edx
  jnz  @MulAndSubLoop

  sub  [ebx], ebp
  mov  ecx, [esp+60]
  mov  ebx, [esp+16]
  mov  [esp+52], esi
  jnc  @RightQhat

  //compensating addition
  dec  [esp+52]                 // todo: more tests needed !!!
  mov  eax, [esp+20]
  xor  esi, esi
  xor  ebp, ebp
@CmpAddLoop:
  mov  edx, [eax+esi*4]
  lea  edi, [esi+ecx]
  add  edx, ebp
  mov  ebp, 0
  adc  ebp, 0
  add  [ebx+edi*4], edx
  adc  ebp, 0
  inc  esi
  cmp  esi, [esp+32]
  jl  @CmpAddLoop

  lea  edi, [esi+ecx]
  add  [ebx+edi*4], ebp

@RightQhat:
  mov  eax, [esp+24]
  mov  edi, [esp+52]
  dec  ecx
  mov  [eax+ecx*4+4], edi
  jge  @mainloop
  ////////////////////////
@done:
  ////////////////////////
  mov  ebp, [esp   ]
  mov  ebx, [esp+ 4]
  mov  esi, [esp+ 8]
  mov  edi, [esp+12]
  add  esp, 64
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  T, Rhat: QWord;
  TDigs:  array[0..1] of DWord absolute T;
  RhDigs: array[0..1] of DWord absolute Rhat;
  dMsLimb, Qhat: DWord;
  I, J, dCount: Integer;
begin
  dCount := Integer(q[0]);
  J := LIMB_PER_VALUE;
  if r[J] = 0 then
    while r[J - 1] = 0 do           //r limb count
      Dec(J);
  dMsLimb := d[Pred(dCount)];
  for I := J - dCount downto 0 do   //Main loop
    begin
      TDigs[1] := r[I + dCount];    //estimation
      TDigs[0] := r[Pred(I + dCount)];
      if TDigs[1] < dMsLimb then
        Qhat := T div QWord(dMsLimb)
      else
        Qhat := MAX_LIMB;
      Rhat := T - QWord(Qhat) * QWord(dMsLimb);
      while (QWord(Qhat) * QWord(d[dCount - 2])) > (Rhat shl BIT_PER_LIMB or r[I + dCount - 2]) do
        begin
          Dec(Qhat);
          Rhat += dMsLimb;
          if RhDigs[1] > 0 then
            break;
        end;
      TDigs[1] := 0;
      for J := 0 to dCount - 1 do
        begin
          T := QWord(Qhat) * QWord(d[J]) + QWord(TDigs[1]);
          TDigs[1] += TLimb(r[I + J] < TDigs[0]);  /////////////////
          r[I + J] -= TDigs[0];
        end;
      TDigs[0] := TLimb(R[I + dCount] < TDigs[1]); ///////////////
      r[I + dCount] -= TDigs[1];
      if TDigs[0] > 0 then  // compensating addition
        begin               // todo: more tests needed !!!
          Dec(Qhat);
          TDigs[1] := 0;
          for J := 0 to dCount - 1 do
            begin
              T := QWord(r[I + J]) + QWord(d[J]) + QWord(TDigs[1]);
              r[I + J] := TDigs[0];
            end;
          r[I + dCount] += TDigs[1];
        end;
      q[I] := Qhat;
    end;
end;
{$ENDIF CPU_INTEL}

class procedure TUInt128.Divide(const a, d: TUInt128; dMsLimbIdx: Integer; out q, r: TUInt128);
var
  tR: TLimbsEx;
  tD: TLimbs128;
  Shift: Integer;
begin
  //normalization
  Shift := NlzLimb(d.FLimbs[dMsLimbIdx]);
  ShortBitShiftLeft(@d, @tD, Shift);
  tR[LIMB_PER_VALUE] := ShortBitShiftLeft(@a, @tR, Shift);
  ///////////////////
  q := Default(TUInt128);
  q.FLimbs[0] := Succ(dMsLimbIdx);
  DoDiv(@tR, @tD, @q);
  ShortBitShiftRight(@tR, @r, Shift);
end;

class procedure TUInt128.DivQ(const a, d: TUInt128; dMsLimbIdx: Integer; out q: TUInt128);
var
  tR: TLimbsEx;
  tD: TLimbs128;
  Shift: Integer;
begin
  //normalization
  Shift := NlzLimb(d.FLimbs[dMsLimbIdx]);
  ShortBitShiftLeft(@d, @tD, Shift);
  tR[LIMB_PER_VALUE] := ShortBitShiftLeft(@a, @tR, Shift);
  ///////////////////
  q := Default(TUInt128);
  q.FLimbs[0] := Succ(dMsLimbIdx);
  DoDiv(@tR, @tD, @q);
end;

class procedure TUInt128.DivR(const a, d: TUInt128; dMsLimbIdx: Integer; out r: TUInt128);
var
  tR: TLimbsEx;
  tD, q: TLimbs128;
  Shift: Integer;
begin
  //normalization
  Shift := NlzLimb(d.FLimbs[dMsLimbIdx]);
  ShortBitShiftLeft(@d, @tD, Shift);
  tR[LIMB_PER_VALUE] := ShortBitShiftLeft(@a, @tR, Shift);
  ///////////////////
  q[0] := Succ(dMsLimbIdx);
  DoDiv(@tR, @tD, @q);
  ShortBitShiftRight(@tR, @r, Shift);
end;

class function TUInt128.DoDivShort(a: PLimb; d: TLimb; q: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
{$IFDEF MSWINDOWS} //a in rcx, d in rdx, q in r8
  mov  r9, rdx     //r9 <- d

  mov  rax, qword ptr[rcx+8]
  xor  rdx, rdx
  div  r9
  mov  qword ptr[r8+8], rax

  mov  rax, qword ptr[rcx]
  div  r9
  mov  qword ptr[r8], rax

  mov  rax, rdx
{$ELSE MSWINDOWS}  //a in rdi, d in rsi, q in rdx
  mov  r8, rdx     //r8 <- q

  mov  rax, qword ptr[rdi+8]
  xor  rdx, rdx
  div  rsi
  mov  qword ptr[r8+8], rax

  mov  rax, qword ptr[rdi]
  div  rsi
  mov  qword ptr[r8], rax

  mov  rax, rdx
{$ENDIF MSWINDOWS}
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8
  mov  [esp  ], esi
  mov  [esp+4], ebx

  mov  esi, eax          //esi <- a
  mov  ebx, edx          //ebx <- d
                         //q in ecx
  mov  eax, [esi+12]
  xor  edx, edx
  div  ebx
  mov  [ecx+12], eax

  mov  eax, [esi+8]
  div  ebx
  mov  [ecx+8], eax

  mov  eax, [esi+4]
  div  ebx
  mov  [ecx+4], eax

  mov  eax, [esi]
  div  ebx
  mov  [ecx], eax

  mov  eax, edx

  mov  esi, [esp  ]
  mov  ebx, [esp+4]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  vA, vQ: QWord;
  aDigs: array[0..1] of TLimb absolute vA;
begin
  aDigs[0] := a[3];
  aDigs[1] := 0;
  vQ := vA div d;
  Q[3] := TLimb(vQ);
  vA -= vQ * QWord(d);

  aDigs[1] := aDigs[0];
  aDigs[0] := a[2];
  vQ := vA div d;
  Q[2] := TLimb(vQ);
  vA -= vQ * QWord(d);

  aDigs[1] := aDigs[0];
  aDigs[0] := a[1];
  vQ := vA div d;
  Q[1] := TLimb(vQ);
  vA -= vQ * QWord(d);

  aDigs[1] := aDigs[0];
  aDigs[0] := a[0];
  vQ := vA div d;
  Q[0] := TLimb(vQ);
  vA -= vQ * QWord(d);

  Result := aDigs[0];
end;
{$ENDIF CPU_INTEL}

class function TUInt128.Limb2Str(aValue: TLimb; aStr: PAnsiChar; aShowLz: Boolean): Integer;
const
  Tbl10: array[0..9] of AnsiChar = '0123456789';
var
  q: TLimb;
begin
  Result := 0;
  while aValue <> 0 do
    begin
      q := aValue div 10;
      aStr[Result] := Tbl10[aValue {%H-}- q*10];
      aValue := q;
      Inc(Result);
    end;
  if aShowLz then
    while Result < STR_CONV_BASE_LOG do
      begin
        aStr[Result] := '0';
        Inc(Result);
      end;
end;

class function TUInt128.Str2Limb(aValue: PAnsiChar; aCount: Integer): TLimb;
var
  I: Integer;
const
  Decimals: array['0'..'9'] of TLimb = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
begin
  if aCount > 0 then
    begin
      Result := Decimals[aValue[0]];
      for I := 1 to aCount - 1 do
        Result := Result * 10 + Decimals[aValue[I]];
    end
  else
    Result := 0;
end;

class function TUInt128.ParseStr(const aValue: string; out aResult: shortstring): TParseResult;
type
  TParseState =
    (psStart, psPlusFound, psSeemsHex, psFirstZeroFound, psDecLeadZeroFound,
     psHexLeadZeroFound, psHexDetected, psDecDetected);
var
  I, rLen: Integer;
  pR, pV: PAnsiChar;
  CurrChar: AnsiChar;
  State: TParseState;
const
  MaxLen = 39;    //39 - maximal TUInt128 decimal string length
  MaxHexLen = 32; //32 - maximal TUInt128 hex string length
begin
  Result := prNan;
  if aValue = '' then
    exit;
  pR := @aResult[1];
  pV := PAnsiChar(aValue);
  State := psStart;
  rLen := 0;
  for I := 0 to Pred(Length(aValue)) do
    begin
      CurrChar := pV[I];
      if CurrChar = ' ' then
        exit;
      case State of
        psStart:
          case CurrChar of
            '+':      State := psPlusFound;
            '0':      State := psFirstZeroFound;
            '$',
            'X','x':  State := psSeemsHex;
            '1'..'9': begin State := psDecDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psPlusFound:
          case CurrChar of
            '0':      State := psFirstZeroFound;
            '$',
            'X','x':  State := psSeemsHex;
            '1'..'9': begin State := psDecDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psSeemsHex:
          case CurrChar of
            '0':      State := psHexLeadZeroFound;
            '1'..'9',
            'A'..'F',
            'a'..'f': begin State := psHexDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psFirstZeroFound:
          case CurrChar of
            '0':      continue;
            'X', 'x': State := psSeemsHex;
            '1'..'9': begin State := psDecDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psDecLeadZeroFound:
          case CurrChar of
            '0':      continue;
            '1'..'9': begin State := psDecDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psHexLeadZeroFound:
          case CurrChar of
            '0':      continue;
            '1'..'9',
            'A'..'F',
            'a'..'f': begin State := psHexDetected; pR[rLen] := CurrChar; Inc(rLen) end;
          else
            exit;
          end;
        psHexDetected:
          if (CurrChar in ['0'..'9', 'A'..'F', 'a'..'f']) and (rLen < MaxHexLen) then
            begin
              pR[rLen] := CurrChar;
              Inc(rLen)
            end
          else
            exit;
        psDecDetected:
          if (CurrChar in ['0'..'9']) and (rLen < MaxLen) then
            begin
              pR[rLen] := CurrChar;
              Inc(rLen)
            end
          else
            exit;
      end;
    end;
  if State < psFirstZeroFound then
    exit;
  if State < psHexDetected then
    exit(prZero);
  SetLength(aResult, rLen);
  if State = psDecDetected then
    Result := prDec
  else
    Result := prHex;
end;

class function TUInt128.TryParseStr(const s: string; out aValue: TLimbs128): Boolean;
var
  prs: shortstring;
begin
  case ParseStr(s, prs) of
    prDec:  exit(TryDec2Val(prs, aValue));
    prHex:  Hex2Val(prs, aValue);
    prZero: TUInt128(aValue) := Default(TUInt128);
  else //prNan
    exit(False);
  end;
  Result := True;
end;

class function TUInt128.TryDec2Val(const s: shortstring; out aValue: TLimbs128): Boolean;
var
  Len, MulCount, StartPos, I: Integer;
begin
  Len := System.Length(s);
  StartPos := 1;
  MulCount := Len div STR_CONV_BASE_LOG;
  Len -= MulCount * STR_CONV_BASE_LOG;
  SetSingleLimb(Str2Limb(@s[StartPos], Len), aValue);
  Inc(StartPos, Len);
  for I := 1 to MulCount do
    begin
      if DoMulShort(@aValue, STR_CONV_BASE, @aValue) <> 0 then
        exit(False);
      if DoAddShort(@aValue, Str2Limb(@s[StartPos], STR_CONV_BASE_LOG), @aValue) <> 0 then
        exit(False);
      StartPos += STR_CONV_BASE_LOG;
    end;
  Result := True;
end;

class procedure TUInt128.Hex2Val(const s: shortstring; out aValue: TLimbs128);
var
  I, J, ByteCnt: Integer;
const
  Table: array['0'..'f'] of Byte = (
     0,1,2,3,4,5,6,7,8,9,0,0,0,0,0,0,0,10,11,12,13,14,15,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,11,12,13,14,15);
begin
  ByteCnt := Length(s) shr 1;
  J := Length(s);
  for I := 0 to Pred(ByteCnt) do
    begin
      TUInt128({%H-}aValue).Bytes[I] := Table[s[J]] or (Table[s[J-1]] shl 4);
      J -= 2;
    end;
  if Odd(Length(s)) then
    begin
      TUInt128(aValue).Bytes[ByteCnt] := Table[s[J]];
      Inc(ByteCnt);
    end;
  for I := ByteCnt to Pred(BYTE_PER_VALUE) do
    TUInt128(aValue).Bytes[I] := 0;
end;

class function TUInt128.Val2Str(const aValue: TLimbs128): string;
var
  q: TLimbs128;
  r: TLimb;
  rLen, I: Integer;
  c: AnsiChar;
begin
  if TUInt128(aValue).IsZero then
    exit('0');
  q := aValue;
  rLen := 0;
  SetLength(Result, 39);
  repeat
    r := DoDivShort(@q, STR_CONV_BASE, @q);
    if not TUInt128(q).IsZero then
      rLen += Limb2Str(r, @Result[Succ(rLen)])
    else
      begin
        rLen += Limb2Str(r, @Result[Succ(rLen)], False);
        break;
      end;
  until False;
  SetLength(Result, rLen);
  I := 1;
  while I < rLen do  //reverse Result
    begin
      c := Result[I];
      Result[I] := Result[rLen];
      Result[rLen] := c;
      Inc(I);
      Dec(rLen);
    end;
end;

class function TUInt128.Val2Hex(const aValue: TLimbs128; aMinDigits: Integer; aShowRadix: Boolean): string;
const
  HexTable: array[0..$0f] of AnsiChar = '0123456789ABCDEF';
var
  I, J, BitLen, NibLen, StrLen: Integer;
  b: Byte;
begin
  BitLen := Succ(MsBitIndex(aValue));
  NibLen := (BitLen shr 2) + Ord((BitLen and 3) <> 0);
  StrLen := NibLen;
  if aMinDigits > StrLen then
    StrLen := aMinDigits;
  System.SetLength(Result, StrLen + Ord(aShowRadix));
  J := System.Length(Result);
  for I := 0 to Pred(NibLen shr 1) do
    begin
      b := TUInt128(aValue).Bytes[I];
      Result[J  ] := HexTable[b and 15];
      Result[J-1] := HexTable[b shr  4];
      J -= 2;
    end;
  if Odd(NibLen) then
    begin
      Result[J] := HexTable[TUInt128(aValue).Bytes[NibLen shr 1] and 15];
      Dec(J);
    end;
  I := Ord(aShowRadix);
  while J > I do
    begin
      Result[J] := '0';
      Dec(J);
    end;
  if aShowRadix then
    Result[J] := '$';
end;

{$POP}{Q-, R-}

class operator TUInt128.=(const L, R: TUInt128): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]) and
            (L.FLimbs[2] = R.FLimbs[2]) and (L.FLimbs[3] = R.FLimbs[3]);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.<>(const L, R: TUInt128): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] <> R.FLimbs[0]) or (L.FLimbs[1] <> R.FLimbs[1]);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] <> R.FLimbs[0]) or (L.FLimbs[1] <> R.FLimbs[1]) or
            (L.FLimbs[2] <> R.FLimbs[2]) or (L.FLimbs[3] <> R.FLimbs[3]);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.>(const L, R: TUInt128): Boolean;
begin
  Result := Cmp(L.FLimbs, R.FLimbs) = 1;
end;

class operator TUInt128.>=(const L, R: TUInt128): Boolean;
begin
  Result := Cmp(L.FLimbs, R.FLimbs) >= 0;
end;

class operator TUInt128.<(const L, R: TUInt128): Boolean;
begin
  Result := Cmp(L.FLimbs, R.FLimbs) = -1;
end;

class operator TUInt128.<=(const L, R: TUInt128): Boolean;
begin
  Result := Cmp(L.FLimbs, R.FLimbs) <= 0;
end;

class operator TUInt128.=(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] = R) and (L.FLimbs[1] = 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] = R) and ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) = 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.<>(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] <> R) or (L.FLimbs[1] <> 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] <> R) or ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) <> 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.>(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] > R) or (L.FLimbs[1] <> 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] > R) or ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) <> 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.>=(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] >= R) or (L.FLimbs[1] <> 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] >= R) or ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) <> 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.<(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] < R) and (L.FLimbs[1] = 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] < R) and ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) = 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.<=(const L: TUInt128; R: DWord): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] <= R) and (L.FLimbs[1] = 0);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] <= R) and ((L.FLimbs[1] or L.FLimbs[2] or L.FLimbs[3]) = 0);
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.:=(const aValue: DWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := aValue;
  Result.FLimbs[1] := 0;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := aValue;
  Result.FLimbs[1] := 0;
  Result.FLimbs[2] := 0;
  Result.FLimbs[3] := 0;
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.:=(const aValue: TUInt128): string;
begin
  Result := Val2Str(aValue.FLimbs);
end;

class operator TUInt128.:=(const aValue: TUInt128): Double;
begin
  Result := aValue.ToDouble;
end;

class operator TUInt128.:=(const aValue: string): TUInt128;
begin
  Result := Parse(aValue);
end;

class operator TUInt128.Inc(const aValue: TUInt128): TUInt128;
begin
{$IFOPT Q+}
  if DoAddShort(@aValue, 1, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoAddShort(@aValue, 1, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.Dec(const aValue: TUInt128): TUInt128;
begin
{$IFOPT Q+}
  if DoSubShort(@aValue, 1, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoSubShort(@aValue, 1, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.shl(const aValue: TUInt128; aDist: Integer): TUInt128;
begin
  aDist := aDist and VALUE_BITSIZE_MASK;
  if aDist <> 0 then
    BitShiftLeft(@aValue, @Result, aDist)
  else
    Result := aValue;
end;

class operator TUInt128.shr(const aValue: TUInt128; aDist: Integer): TUInt128;
begin
  aDist := aDist and VALUE_BITSIZE_MASK;
  if aDist <> 0 then
    BitShiftRight(@aValue, @Result, aDist)
  else
    Result := aValue;
end;

class operator TUInt128.not(const aValue: TUInt128): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := not aValue.FLimbs[0];
  Result.FLimbs[1] := not aValue.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := not aValue.FLimbs[0];
  Result.FLimbs[1] := not aValue.FLimbs[1];
  Result.FLimbs[2] := not aValue.FLimbs[2];
  Result.FLimbs[3] := not aValue.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.and(const L, R: TUInt128): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] and R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] and R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] and R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] and R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.or(const L, R: TUInt128): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] or R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] or R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] or R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] or R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.xor(const L, R: TUInt128): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] xor R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] xor R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] xor R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] xor R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.and(const L: TUInt128; R: DWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R;
  Result.FLimbs[1] := 0;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R;
  Result.FLimbs[1] := 0;
  Result.FLimbs[2] := 0;
  Result.FLimbs[3] := 0;
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.or (const L: TUInt128; R: DWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R;
  Result.FLimbs[1] := L.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R;
  Result.FLimbs[1] := L.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.xor(const L: TUInt128; R: DWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R;
  Result.FLimbs[1] := L.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R;
  Result.FLimbs[1] := L.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TUInt128.+(const L, R: TUInt128): TUInt128;
begin
{$IFOPT Q+}
  if DoAdd(@L, @R, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoAdd(@L, @R, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.+(const L: TUInt128; R: DWord): TUInt128;
begin
  if R = 0 then
    Result := L
{$IFOPT Q+}
  else
    if DoAddShort(@L, R, @Result) <> 0 then
      raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  else
    DoAddShort(@L, R, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.-(const L, R: TUInt128): TUInt128;
begin
{$IFOPT Q+}
  if DoSub(@L, @R, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoSub(@L, @R, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.-(const L: TUInt128; R: DWord): TUInt128;
begin
  if R = 0 then
    Result := L
{$IFOPT Q+}
  else
    if DoSubShort(@L, R, @Result) <> 0 then
      raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  else
    DoSubShort(@L, R, @Result);
{$ENDIF Q+}
end;

class operator  TUInt128.-(const L: TUInt128): TUInt128;
begin
  DoNeg(@L, @Result);
end;

class operator TUInt128.*(const L, R: TUInt128): TUInt128;
begin
{$IFOPT Q+}
  if DoMul(@L, @R, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoMul(@L, @R, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.*(const L: TUInt128; R: DWord): TUInt128;
begin
  if R = 0 then
    exit(Default(TUInt128));
{$IFOPT Q+}
  if DoMulShort(@L, R, @Result) <> 0 then
    raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
  DoMulShort(@L, R, @Result);
{$ENDIF Q+}
end;

class operator TUInt128.div(const aValue, aD: TUInt128): TUInt128;
var
  dMsLimbIdx: Integer;
begin
  dMsLimbIdx := MsLimbIndex(aD.FLimbs);
  if dMsLimbIdx >= 0 then
    begin
      if @aValue = @aD then
        exit(TUInt128(1));
      if dMsLimbIdx = 0 then
        DoDivShort(@aValue, aD.FLimbs[0], @Result)
      else
        case Cmp(aValue.FLimbs, aD.FLimbs) of
          -1: Result := 0;
           0: Result := 1;
        else //1
          DivQ(aValue, aD, dMsLimbIdx, Result);
        end;
    end
  else
    raise EDivByZero.Create(SDivByZero);
end;

class operator TUInt128.mod(const aValue, aD: TUInt128): TUInt128;
var
  dMsLimbIdx: Integer;
  tmp: TLimbs128;
begin
  dMsLimbIdx := MsLimbIndex(aD.FLimbs);
  if dMsLimbIdx >= 0 then
    begin
      if @aValue = @aD then
        exit(Default(TUInt128));
      if dMsLimbIdx = 0 then
        begin
          Result := 0;
          Result.FLimbs[0] := DoDivShort(@aValue, aD.FLimbs[0], @tmp);
        end
      else
        case Cmp(aValue.FLimbs, aD.FLimbs) of
          -1: Result := aValue;
           0: Result := 0;
        else //1
          DivR(aValue, aD, dMsLimbIdx, Result);
        end;
    end
  else
    raise EDivByZero.Create(SDivByZero);
end;

class operator TUInt128.div(const aValue: TUInt128; aD: DWord): TUInt128;
begin
  if aD <> 0 then
    DoDivShort(@aValue, aD, @Result)
  else
    raise EDivByZero.Create(SDivByZero);
end;

class operator TUInt128.mod(const aValue: TUInt128; aD: DWord): DWord;
var
  tmp: TLimbs128;
begin
  if aD <> 0 then
    Result := DoDivShort(@aValue, aD, @tmp)
  else
    raise EDivByZero.Create(SDivByZero);
end;

class function TUInt128.MinValue: TUInt128;
begin
  Result := Default(TUInt128);
end;

class function TUInt128.MaxValue: TUInt128;
const
{$IFDEF USE_LIMB64}
  v: TLimbs128 = (High(TLimb),High(TLimb));
{$ELSE USE_LIMB64}
  v: TLimbs128 = (High(TLimb),High(TLimb),High(TLimb),High(TLimb));
{$ENDIF USE_LIMB64}
begin
  Result.FLimbs := v;
end;

class procedure TUInt128.DivRem(const aValue, aD: TUInt128; out aQ, aR: TUInt128);
var
  dMsLimbIdx: Integer;
begin
  dMsLimbIdx := MsLimbIndex(aD.FLimbs);
  if dMsLimbIdx >= 0 then
    begin
      if @aValue = @aD then
        begin
          aQ := TUInt128(1);
          aR := Default(TUInt128);
          exit;
        end;
      if dMsLimbIdx = 0 then
        begin
          aR := 0;
          aR.FLimbs[0] := DoDivShort(@aValue, aD.FLimbs[0], @aQ);
        end
      else
        case Cmp(aValue.FLimbs, aD.FLimbs) of
          -1:
            begin
              aQ := 0;
              aR := aValue;
            end;
           0:
             begin
               aQ := 1;
               aR := 0;
             end;
        else //1
          Divide(aValue, aD, dMsLimbIdx, aQ, aR);
        end
    end
  else
    raise EDivByZero.Create(SDivByZero);
end;

class function TUInt128.DivRem(const aValue: TUInt128; aD: DWord; out aQ: TUInt128): DWord;
begin
  if aD <> 0 then
    Result := DoDivShort(@aValue, aD, @aQ)
  else
    raise EDivByZero.Create(SDivByZero);
end;

class function TUInt128.Encode(aLo: QWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := aLo;
  Result.FLimbs[1] := 0;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := TLimb(aLo);
  Result.FLimbs[1] := TLimb(aLo shr BIT_PER_LIMB);
  Result.FLimbs[2] := 0;
  Result.FLimbs[3] := 0;
{$ENDIF USE_LIMB64}
end;

class function TUInt128.Encode(aLo, aHi: QWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := aLo;
  Result.FLimbs[1] := aHi;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := TLimb(aLo);
  Result.FLimbs[1] := TLimb(aLo shr BIT_PER_LIMB);
  Result.FLimbs[2] := TLimb(aHi);
  Result.FLimbs[3] := TLimb(aHi shr BIT_PER_LIMB);
{$ENDIF USE_LIMB64}
end;

class function TUInt128.Encode(v0, v1, v2, v3: DWord): TUInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := TLimb(v0) or TLimb(v1) shl 32;
  Result.FLimbs[1] := TLimb(v2) or TLimb(v3) shl 32;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := v0;
  Result.FLimbs[1] := v1;
  Result.FLimbs[2] := v2;
  Result.FLimbs[3] := v3;
{$ENDIF USE_LIMB64}
end;

class function TUInt128.Random: TUInt128;
begin
  Result := Encode(BJNextRandom, BJNextRandom, BJNextRandom, BJNextRandom);
end;

class function TUInt128.RandomInRange(const aRange: TUInt128): TUInt128;
var
  MsDWordIdx, I: Integer;
  Mask: DWord;
begin
  if aRange < 2 then
    exit(0);
  MsDWordIdx := Pred(DWORD_PER_VALUE);
  while aRange.DWords[MsDWordIdx] = 0 do
    Dec(MsDWordIdx);
  Result := Default(TUInt128);
  for I := 0 to Pred(MsDWordIdx) do
    Result.DWords[I] := BJNextRandom;
  Mask := Pred(DWord(1) shl Succ(BsrDword(aRange.DWords[MsDWordIdx])));
  repeat
    Result.DWords[MsDWordIdx] := BJNextRandom and Mask;
  until Result < aRange;
end;

class function TUInt128.Parse(const s: string): TUInt128;
begin
  if not TryParse(s, Result) then
    raise EConvertError.CreateFmt(SInvalidInteger, [s]);
end;

class function TUInt128.TryParse(const s: string; out aValue: TUInt128): Boolean;
begin
  Result := TryParseStr(s, aValue.FLimbs);
end;

class function TUInt128.Compare(const L, R: TUInt128): SizeInt;
begin
  Result := Cmp(L.FLimbs, R.FLimbs);
end;

class function TUInt128.Equal(const L, R: TUInt128): Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]) and
            (L.FLimbs[2] = R.FLimbs[2]) and (L.FLimbs[3] = R.FLimbs[3]);
{$ENDIF USE_LIMB64}
end;

class function TUInt128.HashCode(const aValue: TUInt128): SizeInt;
begin
{$IFDEF FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := TxxHash32LE.HashBuf(@aValue, SizeOf(aValue));
{$ELSE FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := TxxHash32LE.HashGuid(TGuid(aValue));
{$ENDIF FPC_REQUIRES_PROPER_ALIGNMENT}
end;

function TUInt128.Lo: QWord;
begin
{$IFDEF USE_LIMB64}
  Result := FLimbs[0];
{$ELSE USE_LIMB64}
  Result := QWord(FLimbs[0]) or QWord(FLimbs[1]) shl BIT_PER_LIMB;
{$ENDIF USE_LIMB64}
end;

function TUInt128.Hi: QWord;
begin
{$IFDEF USE_LIMB64}
  Result := FLimbs[1];
{$ELSE USE_LIMB64}
  Result := QWord(FLimbs[2]) or QWord(FLimbs[3]) shl BIT_PER_LIMB;
{$ENDIF USE_LIMB64}
end;

function TUInt128.IsZero: Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := FLimbs[0] or FLimbs[1] = 0;
{$ELSE USE_LIMB64}
  Result := FLimbs[0] or FLimbs[1] or FLimbs[2] or FLimbs[3] = 0;
{$ENDIF USE_LIMB64}
end;

procedure TUInt128.SetZero;
begin
  FLimbs := Default(TLimbs128);
end;

procedure TUInt128.Negate;
begin
  DoNeg(@FLimbs, @FLimbs);
end;

function TUInt128.IsOdd: Boolean;
begin
  Result := Boolean(FLimbs[0] and 1);
end;

function TUInt128.IsTwoPower: Boolean;
begin
  Result := PopCount = 1;
end;

function TUInt128.PopCount: Integer;
begin
{$IFDEF USE_LIMB64}
  Result := Integer(PopCnt(FLimbs[0])) + Integer(PopCnt(FLimbs[1]));
{$ELSE USE_LIMB64}
  Result := Integer(PopCnt(FLimbs[0])) + Integer(PopCnt(FLimbs[1])) +
            Integer(PopCnt(FLimbs[2])) + Integer(PopCnt(FLimbs[3]));
{$ENDIF USE_LIMB64}
end;

function TUInt128.BitLength: Integer;
begin
  Result := Succ(MsBitIndex(FLimbs));
end;

function TUInt128.ToDouble: Double;
const
  Basis: Double = Double($100000000);
var
  p: PDWord;
begin
  p := PDWord(@FLimbs);
  Result := ((Double(p[3]) * Basis + Double(p[2])) * Basis + Double(p[1])) * Basis + Double(p[0]);
end;

function TUInt128.ToExtended: Extended;
const
  Basis: Double = Extended($100000000);
var
  p: PDWord;
begin
  p := PDWord(@FLimbs);
  Result := ((Extended(p[3]) * Basis + Extended(p[2])) * Basis + Extended(p[1])) * Basis + Extended(p[0]);
end;

function TUInt128.ToString: string;
begin
  Result := Val2Str(FLimbs);
end;

function TUInt128.ToHexString(aMinDigits: Integer; aShowRadix: Boolean): string;
begin
  Result := Val2Hex(FLimbs, aMinDigits, aShowRadix);
end;

function TUInt128.ToHexString(aShowRadix: Boolean): string;
begin
  Result := Val2Hex(FLimbs, SizeOf(TUInt128) * 2, aShowRadix);
end;

{ TInt128 }

{$IFDEF USE_LIMB64}
  {$DEFINE HiLimbMacro := FLimbs[1]}
{$ELSE USE_LIMB64}
  {$DEFINE HiLimbMacro := FLimbs[3]}
{$ENDIF USE_LIMB64}

function TInt128.GetBit(aIndex: Integer): Boolean;
begin
  Result := TUInt128(FLimbs).GetBit(aIndex);
end;

procedure TInt128.SetBit(aIndex: Integer; aValue: Boolean);
begin
  TUInt128(FLimbs).SetBit(aIndex, aValue);
end;

function TInt128.GetByte(aIndex: Integer): Byte;
begin
  Result := TUInt128(FLimbs).GetByte(aIndex);
end;

procedure TInt128.SetByte(aIndex: Integer; aValue: Byte);
begin
  TUInt128(FLimbs).SetByte(aIndex, aValue);
end;

function TInt128.GetDWord(aIndex: Integer): DWord;
begin
  Result := TUInt128(FLimbs).GetDWord(aIndex);
end;

procedure TInt128.SetDWord(aIndex: Integer; aValue: DWord);
begin
  TUInt128(FLimbs).SetDWord(aIndex, aValue);
end;

function TInt128.GetNormLimbs: TLimbs128;
begin
  Result := FLimbs;
{$IFDEF USE_LIMB64}
  if Result[0] or (Result[1] and SIGN_MASK) = 0 then
    Result[1] := 0;
{$ELSE USE_LIMB64}
  if Result[0] or Result[1] or Result[2] or (Result[3] and SIGN_MASK) = 0 then
    Result[3] := 0;
{$ENDIF USE_LIMB64}
end;

class function TInt128.Cmp(const L, R: TInt128): TCompare;
var
  LSign, RSign: TValueSign;
begin
  LSign := L.Sign;
  RSign := R.Sign;
  if LSign <> RSign then
    begin
      if LSign > RSign then
        exit(1);
      exit(-1);
    end;
  if LSign > 0 then
    exit(TUInt128.Cmp(L.FLimbs, R.FLimbs));
  if LSign < 0 then
    exit(TUInt128.Cmp(R.FLimbs, L.FLimbs));
  Result := 0;
end;

class function TInt128.Cmp(const L: TInt128; R: Integer): TCompare;
var
  LNeg, LIsSingleLimb: Boolean;
begin
  if R = 0 then
    exit(L.Sign);
  LNeg := L.HiLimbMacro and SIGN_FLAG <> 0;
  if LNeg xor (R < 0) then
    begin
      if LNeg then
       exit(-1);
      Result := 1;
    end
  else
    begin
{$IFDEF USE_LIMB64}
      LIsSingleLimb := L.FLimbs[1] and SIGN_MASK = 0;
{$ELSE USE_LIMB64}
      LIsSingleLimb := L.FLimbs[1] or L.FLimbs[2] or (L.FLimbs[3] and SIGN_MASK) = 0;
{$ENDIF USE_LIMB64}
      if LIsSingleLimb then
        begin
          if LNeg then
            begin
              if L.FLimbs[0] > TLimb(-TLimb(R)) then
                exit(-1);
              if L.FLimbs[0] < TLimb(-TLimb(R)) then
                exit(1);
              exit(0);
            end;
          if L.FLimbs[0] > TLimb(R) then
            exit(1);
          if L.FLimbs[0] < TLimb(R) then
            exit(-1);
          exit(0);
        end;
      if LNeg then
        exit(-1);
      Result := 1;
    end;
end;

{$PUSH}{$Q-}{$R-}
class procedure TInt128.DoAdd(a, b, s: PLimb);
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
  mov  r10, $7fffffffffffffff
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, s in r8
  mov  r9, qword ptr[rcx]
  add  r9, qword ptr[rdx]
  mov  qword ptr[r8], r9      //0
  setc al

  mov  r9, qword ptr[rcx+8]
  and  r9, r10
  add  r9, rax
  and  r10, qword ptr[rdx+8]
  add  r9, r10
  mov  qword ptr[r8+8], r9    //1
{$ELSE MSWINDOWS}    //a in rdi, b in rsi, s in rdx
  mov  rcx, qword ptr[rdi]
  add  rcx, qword ptr[rsi]
  mov  qword ptr[rdx], rcx    //0
  setc al

  mov  rcx, qword ptr[rdi+8]
  and  rcx, r10
  add  rcx, rax
  and  r10, qword ptr[rsi+8]
  add  rcx, r10
  mov  qword ptr[rdx+8], rcx  //1
{$ENDIF MSWINDOWS}
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8
  mov  [esp], ebx    //a in eax, b in edx, s in ecx

  mov  ebx, [eax]
  add  ebx, [edx]
  mov  [ecx], ebx    //0

  mov  ebx, [eax+4]
  adc  ebx, [edx+4]
  mov  [ecx+4], ebx  //1

  mov  ebx, [eax+8]
  adc  ebx, [edx+8]
  mov  [ecx+8], ebx  //2


  mov  ebx, [eax+12]
  mov  eax, 0
  setc al
  and  ebx, $7fffffff
  add  ebx, eax
  mov  edx, [edx+12]
  and  edx, $7fffffff
  add  ebx, edx
  mov  [ecx+12], ebx //3

  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v, c: TLimb;
begin
  v := a[0];
  s[0] := v + b[0];
  c := TLimb(s[0] < v);

  v := a[1] + c;
  c := TLimb(v < c);
  s[1] := v + b[1];
  c += TLimb(s[1] < v);

  v := a[2] + c;
  c := TLimb(v < c);
  s[2] := v + b[2];
  c += TLimb(s[2] < v);

  s[3] := c + a[3] and SIGN_MASK + b[3] and SIGN_MASK;
end;
{$ENDIF CPU_INTEL}

class procedure TInt128.DoAddShort(a: PLimb; b: TLimb; s: PLimb);
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
  mov  r9, $7fffffffffffffff
{$IFDEF MSWINDOWS} //a in rcx, b in rdx, s in r8
  add  rdx, qword ptr[rcx]
  mov  qword ptr[r8], rdx
  setc al

  mov  rdx, qword ptr[rcx+8]
  and  rdx, r9
  add  rdx, rax
  mov  qword ptr[r8+8], rdx
{$ELSE MSWINDOWS}  //a in rdi, b in rsi, s in rdx
  add  rsi, qword ptr[rdi]
  mov  qword ptr[rdx], rsi
  setc al

  mov  rsi, qword ptr[rdi+8]
  and  rsi, r9
  add  rsi, rax
  mov  qword ptr[rdx+8], rsi
{$ENDIF MSWINDOWS}
end;
  {$ELSE CPUX64}
asm  //a in eax, b in edx, s in ecx
  add  edx, [eax]
  mov  [ecx], edx

  mov  edx, [eax+4]
  adc  edx, 0
  mov  [ecx+4], edx

  mov  edx, [eax+8]
  adc  edx, 0
  mov  [ecx+8], edx

  mov  edx, [eax+12]
  mov  eax, 0
  setc al
  and  edx, $7fffffff
  add  edx, eax
  mov  [ecx+12], edx
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
begin
  s[0] := b + a[0];
  b := TLimb(s[0] < b);

  s[1] := b + a[1];
  b := TLimb(s[1] < b);

  s[2] := b + a[2];

  s[3] := TLimb(s[2] < b) + a[3] and SIGN_MASK;
end;
{$ENDIF CPU_INTEL}

class function TInt128.DoSub(a, b, d: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
  mov  r10, $7fffffffffffffff
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, d in r8
  mov  r9, qword ptr[rcx]
  sub  r9, qword ptr[rdx]
  mov  qword ptr[r8], r9     //0
  setc al

  mov  r9, qword ptr[rcx+8]
  mov  rdx,qword ptr[rdx+8]
  and  r9, r10
  and  rdx,r10
  inc  r10
  sub  r9, rax
  xor  rax, rax
  sub  r9, rdx
  mov  qword ptr[r8+8], r9   //1
  and  r9, r10
  jz   @done

  neg  qword ptr[r8]
  sbb  rax, qword ptr[r8+8]
  mov  qword ptr[r8+8], rax
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, d in rdx
  mov  rcx, qword ptr[rdi]
  sub  rcx, qword ptr[rsi]
  mov  qword ptr[rdx], rcx   //0
  setc al

  mov  rcx, qword ptr[rdi+8]
  mov  rsi, qword ptr[rsi+8]
  and  rcx, r10
  and  rsi, r10
  inc  r10
  sub  rcx, rax
  xor  rax, rax
  sub  rcx, rsi
  mov  qword ptr[rdx+8], rcx //3
  and  rcx, r10
  jz   @done

  neg  qword ptr[rdx]
  sbb  rax, qword ptr[rdx+8]
  mov  qword ptr[rdx+8], rax
{$ENDIF MSWINDOWS}
  mov  rax, 1
@done:
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8
  mov  [esp], ebx    //a in eax, b in edx, d in ecx

  mov  ebx, [eax]
  sub  ebx, [edx]
  mov  [ecx], ebx    //0

  mov  ebx, [eax+4]
  sbb  ebx, [edx+4]
  mov  [ecx+4], ebx  //1

  mov  ebx, [eax+8]
  sbb  ebx, [edx+8]
  mov  [ecx+8], ebx  //2

  mov  ebx, [eax+12]
  mov  eax, 0
  mov  edx, [edx+12]
  setc al
  and  ebx, $7fffffff
  and  edx, $7fffffff
  sub  ebx, eax
  xor  eax, eax
  sub  ebx, edx
  mov  [ecx+12], ebx //3
  and  ebx, $80000000
  jz   @done

  xor  edx, edx
  xor  ebx, ebx
  neg  dword ptr[ecx]
  sbb  edx, [ecx+4]
  sbb  ebx, [ecx+8]
  sbb  eax, [ecx+12]
  mov  [ecx+4], edx
  mov  [ecx+8], ebx
  mov  [ecx+12], eax

  mov  eax, 1
@done:
  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v, brw: TLimb;
begin
  v := a[0] - b[0];
  brw := TLimb(v > a[0]);
  d[0] := v;

  v := a[1] - brw;
  brw := TLimb(v > a[1]);
  d[1] := v - b[1];
  brw += TLimb(d[1] > v);

  v := a[2] - brw;
  brw := TLimb(v > a[2]);
  d[2] := v - b[2];
  brw += TLimb(d[2] > v);

  v := (a[3] and SIGN_MASK) - (b[3] and SIGN_MASK) - brw;
  d[3] := v;

  if v and SIGN_FLAG = 0 then
    exit(0);

  brw := TLimb(d[0] <> 0);
  d[0] := -d[0];

  v := -d[1];
  d[1] := v - brw;
  brw := TLimb(v <> 0) or (TLimb(d[1] > v));

  v := -d[2];
  d[2] := v - brw;
  brw := TLimb(v <> 0) or (TLimb(d[2] > v));

  d[3] := -d[3] - brw;

  Result := 1;
end;
{$ENDIF CPU_INTEL}

class function TInt128.DoSubShort(a: PLimb; b: TLimb; d: PLimb): TLimb;
{$IFDEF CPU_INTEL}register; assembler; nostackframe;
  {$IFDEF CPUX64}
asm
  xor  rax, rax
  mov  r10, $7fffffffffffffff
{$IFDEF MSWINDOWS}  //a in rcx, b in rdx, d in r8

  mov  r9, qword ptr[rcx]
  sub  r9, rdx
  mov  qword ptr[r8], r9     //0
  setc al

  mov  r9, qword ptr[rcx+8]
  and  r9, r10
  inc  r10
  sub  r9, rax
  xor  rax, rax
  mov  qword ptr[r8+8], r9   //1
  and  r9, r10
  jz   @done

  neg  qword ptr[r8]
  sbb  rax, qword ptr[r8+8]
  mov  qword ptr[r8+8], rax
{$ELSE MSWINDOWS}   //a in rdi, b in rsi, d in rdx
  mov  rcx, qword ptr[rdi]
  sub  rcx, rsi
  mov  qword ptr[rdx], rcx   //0
  setc al

  mov  rcx, qword ptr[rdi+8]
  and  rcx, r10
  inc  r10
  sub  rcx, rax
  xor  rax, rax
  mov  qword ptr[rdx+8], rcx //1
  and  rcx, r10
  jz   @done

  neg  qword ptr[rdx]
  sbb  rax, qword ptr[rdx+8]
  mov  qword ptr[rdx+8], rax
{$ENDIF MSWINDOWS}
  mov  rax, 1
@done:
end;
  {$ELSE CPUX64}
asm
  sub  esp, 8         //a in eax, b in edx, d in ecx
  mov  [esp], ebx

  mov  ebx, [eax]
  sub  ebx, edx
  mov  [ecx], ebx     //0

  mov  ebx, [eax+4]
  sbb  ebx, 0
  mov  [ecx+4], ebx   //1

  mov  ebx, [eax+8]
  sbb  ebx, 0
  mov  [ecx+8], ebx   //2

  mov  ebx, [eax+12]
  mov  eax, 0
  setc al
  and  ebx, $7fffffff
  sub  ebx, eax
  xor  eax, eax
  test ebx, $80000000
  mov  [ecx+12], ebx  //3
  jz   @done

  xor  ebx, ebx
  xor  edx, edx
  neg  dword ptr[ecx]
  sbb  eax, [ecx+4]
  sbb  ebx, [ecx+8]
  sbb  edx, [ecx+12]
  mov  [ecx+4], eax
  mov  [ecx+8], ebx
  mov  [ecx+12], edx
  mov  eax, 1
@done:
  mov  ebx, [esp]
  add  esp, 8
end;
  {$ENDIF CPUX64}
{$ELSE CPU_INTEL}
var
  v: TLimb;
begin
  v := a[0];
  d[0] := v - b;
  b := TLimb(d[0] > v);

  v := a[1];
  d[1] := v - b;
  b := TLimb(d[1] > v);

  v := a[2];
  d[2] := v - b;
  b := TLimb(d[2] > v);


  d[3] := (a[3] and SIGN_MASK) - b;
  if d[3] and SIGN_FLAG = 0 then
    exit(0);

  b := TLimb(d[0] <> 0);
  d[0] := -d[0];

  v := -d[1];
  d[1] := v - b;
  b := TLimb(v <> 0) or (TLimb(d[1] > v));

  v := -d[2];
  d[2] := v - b;
  b := TLimb(v <> 0) or (TLimb(d[2] > v));

  d[3] := -d[3] - b;
  Result := 1;
end;
{$ENDIF CPU_INTEL}{$POP}{Q-, R-}

class procedure TInt128.Add(const a, b: TInt128; out s: TInt128);
var
  ANeg, BNeg: Boolean;
begin
  ANeg := a.HiLimbMacro and SIGN_FLAG <> 0;
  BNeg := b.HiLimbMacro and SIGN_FLAG <> 0;
  if ANeg xor BNeg then
    begin
      if ANeg xor (DoSub(@a, @b, @s) <> 0) then
        s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
    end
  else
    begin
      DoAdd(@a, @b, @s);
{$IFOPT Q+}
      if s.HiLimbMacro and SIGN_FLAG = 0 then
        begin
          if ANeg then
            s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
        end
      else
        raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
      if ANeg then
        s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
{$ENDIF Q+}
    end;
end;

class procedure TInt128.AddShort(const a: TInt128; b: Integer; out s: TInt128);
var
  ANeg: Boolean;
begin
  if b = 0 then
    begin
      s := a;
      exit;
    end;
  ANeg := a.HiLimbMacro and SIGN_FLAG <> 0;
  if ANeg xor (b < 0) then
    begin
      if ANeg then
        begin
          if DoSubShort(@a, b, @s) = 0 then
            s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
        end
      else
        begin
          if DoSubShort(@a, -TLimb(b), @s) <> 0 then
            s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
        end;
    end
  else
    begin
      if ANeg then
        DoAddShort(@a, -TLimb(b), @s)
      else
        DoAddShort(@a, b, @s);
{$IFOPT Q+}
      if s.HiLimbMacro and SIGN_FLAG = 0 then
        begin
          if ANeg then
            s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
        end
      else
        raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
      if ANeg then
        s.HiLimbMacro := s.HiLimbMacro or SIGN_FLAG;
{$ENDIF Q+}
    end;
end;

class procedure TInt128.Sub(const a, b: TInt128; out d: TInt128);
var
  ANeg, BNeg: Boolean;
begin
  ANeg := a.HiLimbMacro and SIGN_FLAG <> 0;
  BNeg := b.HiLimbMacro and SIGN_FLAG <> 0;
  if ANeg xor BNeg then
    begin
      DoAdd(@a, @b, @d);
{$IFOPT Q+}
      if d.HiLimbMacro and SIGN_FLAG = 0 then
        begin
          if ANeg then
            d.HiLimbMacro := d.HiLimbMacro or SIGN_FLAG;
        end
      else
        raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
      if ANeg then
        d.HiLimbMacro := d.HiLimbMacro or SIGN_FLAG;
{$ENDIF Q+}
    end
  else
    if ANeg xor (DoSub(@a, @b, @d) <> 0) then
      d.HiLimbMacro := d.HiLimbMacro or SIGN_FLAG;
end;

class procedure TInt128.SubShort(const a: TInt128; b: Integer; out d: TInt128);
var
  ANeg: Boolean;
begin
  if b = 0 then
    begin
      d := a;
      exit;
    end;
  ANeg := a.HiLimbMacro and SIGN_FLAG <> 0;
  if ANeg xor (b < 0) then
    begin
      if ANeg then
        DoAddShort(@a, b, @d)
      else
        DoAddShort(@a, -TLimb(b), @d);
{$IFOPT Q+}
      if d.HiLimbMacro and SIGN_FLAG = 0 then
        begin
          if ANeg then
            d.HiLimbMacro := d.HiLimbMacro or SIGN_FLAG;
        end
      else
        raise EIntOverflow.Create(SIntOverflow);
{$ELSE Q+}
      if ANeg then
        d.HiLimbMacro := d.HiLimbMacro or SIGN_FLAG;
{$ENDIF Q+}
    end
  else
    begin
      if ANeg then
        begin
          if DoSubShort(@a, -TLimb(b), @d) = 0 then
            d.HiLimbMacro := d.HiLimbMacro xor SIGN_FLAG;
        end
      else
        begin
          if DoSubShort(@a, b, @d) <> 0 then
            d.HiLimbMacro := d.HiLimbMacro xor SIGN_FLAG;
        end;
    end;
end;

class procedure TInt128.DoMul(a, b, p: PInt128);
var
  ANeg, BNeg: Boolean;
begin
  ANeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  BNeg := b^.HiLimbMacro and SIGN_FLAG <> 0;
  b^.HiLimbMacro := b^.HiLimbMacro and SIGN_MASK;
  try
  {$IFOPT Q+}
    if (TUInt128.DoMul(PLimb(a), PLimb(b), PLimb(p)) <> 0) or (p^.HiLimbMacro and SIGN_FLAG <> 0) then
      raise EIntOverflow.Create(SIntOverflow);
  {$ELSE Q+}
    TUInt128.DoMul(PLimb(a), PLimb(b), PLimb(p));
  {$ENDIF Q+}
    if ANeg xor BNeg then
      p^.HiLimbMacro := p^.HiLimbMacro or SIGN_FLAG;
  finally
    if ANeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
    if BNeg then
      b^.HiLimbMacro := b^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class procedure TInt128.DoMulShort(a: PInt128; b: Integer; p: PInt128);
var
  ANeg: Boolean;
begin
  if b = 0 then
    begin
      p^ := Default(TInt128);
      exit;
    end;
  ANeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  try
  {$IFOPT Q+}
    if b > 0 then
      begin
        if (TUInt128.DoMulShort(PLimb(a), TLimb(b), PLimb(p)) <> 0) or (p^.HiLimbMacro and SIGN_FLAG <> 0) then
         raise EIntOverflow.Create(SIntOverflow);
      end
    else
      if (TUInt128.DoMulShort(PLimb(a), -TLimb(b), PLimb(p)) <> 0) or (p^.HiLimbMacro and SIGN_FLAG <> 0) then
       raise EIntOverflow.Create(SIntOverflow);
  {$ELSE Q+}
    if b > 0 then
      TUInt128.DoMulShort(PLimb(a), TLimb(b), PLimb(p))
    else
      TUInt128.DoMulShort(PLimb(a), -TLimb(b), PLimb(p));
  {$ENDIF Q+}
    if ANeg xor (b < 0) then
      p^.HiLimbMacro := p^.HiLimbMacro or SIGN_FLAG;
  finally
    if ANeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class procedure TInt128.Divide(a, d, q, r: PInt128);
var
  aNeg, dNeg: Boolean;
begin
  aNeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  dNeg := d^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  d^.HiLimbMacro := d^.HiLimbMacro and SIGN_MASK;
  try
    TUInt128.DivRem(PUInt128(a)^, PUInt128(d)^, PUInt128(q)^, PUInt128(r)^);
    if aNeg xor dNeg then
      q^.HiLimbMacro := q^.HiLimbMacro or SIGN_FLAG;
    if aNeg then
      r^.HiLimbMacro := r^.HiLimbMacro or SIGN_FLAG;
  finally
    if aNeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
    if dNeg then
      d^.HiLimbMacro := d^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class procedure TInt128.DivQ(a, d, q: PInt128);
var
  aNeg, dNeg: Boolean;
begin
  aNeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  dNeg := d^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  d^.HiLimbMacro := d^.HiLimbMacro and SIGN_MASK;
  try
    PUInt128(q)^ := PUInt128(a)^ div PUInt128(d)^;
    if aNeg xor dNeg then
      q^.HiLimbMacro := q^.HiLimbMacro or SIGN_FLAG;
  finally
    if aNeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
    if dNeg then
      d^.HiLimbMacro := d^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class procedure TInt128.DivR(a, d, r: PInt128);
var
  aNeg, dNeg: Boolean;
begin
  aNeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  dNeg := d^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  d^.HiLimbMacro := d^.HiLimbMacro and SIGN_MASK;
  try
    PUInt128(r)^ := PUInt128(a)^ mod PUInt128(d)^;
    if aNeg then
      r^.HiLimbMacro := r^.HiLimbMacro or SIGN_FLAG;
  finally
    if aNeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
    if dNeg then
      d^.HiLimbMacro := d^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class function TInt128.DivShort(a: PInt128; d: Integer; q: PInt128): Integer;
var
  aNeg, dNeg: Boolean;
begin
  aNeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  dNeg := d < 0;
  try
    if dNeg then
      Result := Integer(TUInt128.DivRem(PUInt128(a)^, -DWord(d), PUInt128(q)^))
    else
      Result := Integer(TUInt128.DivRem(PUInt128(a)^, DWord(d), PUInt128(q)^));
    if aNeg xor dNeg then
      q^.HiLimbMacro := q^.HiLimbMacro or SIGN_FLAG;
    if aNeg then
      Result := -Result;
  finally
    if aNeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class procedure TInt128.DivShortQ(a: PInt128; d: Integer; q: PInt128);
var
  aNeg, dNeg: Boolean;
begin
  aNeg := a^.HiLimbMacro and SIGN_FLAG <> 0;
  a^.HiLimbMacro := a^.HiLimbMacro and SIGN_MASK;
  dNeg := d < 0;
  try
    if dNeg then
      PUInt128(q)^ := PUInt128(a)^ div -DWord(d)
    else
      PUInt128(q)^ := PUInt128(a)^ div DWord(d);
    if aNeg xor dNeg then
      q^.HiLimbMacro := q^.HiLimbMacro or SIGN_FLAG;
  finally
    if aNeg then
      a^.HiLimbMacro := a^.HiLimbMacro or SIGN_FLAG;
  end;
end;

class function TInt128.DivShortR(a: PInt128; d: Integer): Integer;
var
  tmp: TUInt128;
  aNeg: Boolean;
begin
  tmp := TUInt128(a^);
  aNeg := tmp.HiLimbMacro and SIGN_FLAG <> 0;
  if aNeg then
    tmp.HiLimbMacro := tmp.HiLimbMacro and SIGN_MASK;
  if d > 0 then
    Result := Integer(tmp mod DWord(d))
  else
    Result := Integer(tmp mod DWord(-d));
  if aNeg then
    Result := -Result;
end;

class operator TInt128.=(const L, R: TInt128): Boolean;
begin
  if L.IsZero then
    exit(R.IsZero);
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] = R.FLimbs[0]) and (L.FLimbs[1] = R.FLimbs[1]) and
            (L.FLimbs[2] = R.FLimbs[2]) and (L.FLimbs[3] = R.FLimbs[3]);
{$ENDIF USE_LIMB64}
end;

class operator TInt128.<>(const L, R: TInt128): Boolean;
begin
  if L.IsZero then
    exit(not R.IsZero);
{$IFDEF USE_LIMB64}
  Result := (L.FLimbs[0] <> R.FLimbs[0]) or (L.FLimbs[1] <> R.FLimbs[1]);
{$ELSE USE_LIMB64}
  Result := (L.FLimbs[0] <> R.FLimbs[0]) or (L.FLimbs[1] <> R.FLimbs[1]) or
            (L.FLimbs[2] <> R.FLimbs[2]) or (L.FLimbs[3] <> R.FLimbs[3]);
{$ENDIF USE_LIMB64}
end;

class operator TInt128.>(const L, R: TInt128): Boolean;
begin
  Result := Cmp(L, R) = 1;
end;

class operator TInt128.>=(const L, R: TInt128): Boolean;
begin
  Result := Cmp(L, R) >= 0;
end;

class operator TInt128.<(const L, R: TInt128): Boolean;
begin
  Result := Cmp(L, R) = -1;
end;

class operator TInt128.<=(const L, R: TInt128): Boolean;
begin
  Result := Cmp(L, R) <= 0;
end;

class operator TInt128.=(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) = 0;
end;

class operator TInt128.<>(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) <> 0;
end;

class operator TInt128.>(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) = 1;
end;

class operator TInt128.>=(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) >= 0;
end;

class operator TInt128.<(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) = -1;
end;

class operator TInt128.<=(const L: TInt128; R: Integer): Boolean;
begin
  Result := Cmp(L, R) <= 0;
end;

class operator TInt128.:=(const aValue: Integer): TInt128;
begin
  if aValue > 0 then
    TUInt128(Result) := TUInt128.Encode(aValue, 0, 0, 0)
  else
    if aValue < 0 then
      TUInt128(Result) := TUInt128.Encode(-DWord(aValue), 0, 0, $80000000)
    else
      Result := Default(TInt128);
end;

class operator TInt128.:=(const aValue: TInt128): Double; inline;
begin
  Result := aValue.ToDouble;
end;

class operator TInt128.:=(const aValue: TInt128): string; inline;
begin
  Result := aValue.ToString;
end;

class operator TInt128.:=(const aValue: string): TInt128; inline;
begin
  Result := Parse(aValue)
end;

class operator TInt128.Inc(const aValue: TInt128): TInt128;
begin
  AddShort(aValue, 1, Result);
end;

class operator TInt128.Dec(const aValue: TInt128): TInt128;
begin
  AddShort(aValue, -1, Result);
end;

class operator TInt128.shl(const aValue: TInt128; aDist: Integer): TInt128;
begin
  aDist := aDist and TUInt128.VALUE_BITSIZE_MASK;
  if aDist <> 0 then
    TUInt128.BitShiftLeft(@aValue, @Result, aDist)
  else
    Result := aValue;
end;

class operator TInt128.shr(const aValue: TInt128; aDist: Integer): TInt128;
begin
  aDist := aDist and TUInt128.VALUE_BITSIZE_MASK;
  if aDist <> 0 then
    TUInt128.BitShiftRight(@aValue, @Result, aDist)
  else
    Result := aValue;
end;

class operator TInt128.not(const aValue: TInt128): TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := not aValue.FLimbs[0];
  Result.FLimbs[1] := not aValue.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := not aValue.FLimbs[0];
  Result.FLimbs[1] := not aValue.FLimbs[1];
  Result.FLimbs[2] := not aValue.FLimbs[2];
  Result.FLimbs[3] := not aValue.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TInt128.and(const L, R: TInt128): TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] and R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] and R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] and R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] and R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] and R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TInt128.or(const L, R: TInt128): TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] or R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] or R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] or R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] or R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] or R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator TInt128.xor(const L, R: TInt128): TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] xor R.FLimbs[1];
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := L.FLimbs[0] xor R.FLimbs[0];
  Result.FLimbs[1] := L.FLimbs[1] xor R.FLimbs[1];
  Result.FLimbs[2] := L.FLimbs[2] xor R.FLimbs[2];
  Result.FLimbs[3] := L.FLimbs[3] xor R.FLimbs[3];
{$ENDIF USE_LIMB64}
end;

class operator  TInt128.+(const L, R: TInt128): TInt128;
begin
  Add(L, R, Result);
end;

class operator  TInt128.+(const L: TInt128; R: Integer): TInt128;
begin
  AddShort(L, R, Result);
end;

class operator  TInt128.-(const L, R: TInt128): TInt128;
begin
  Sub(L, R, Result);
end;

class operator  TInt128.-(const L: TInt128; R: Integer): TInt128;
begin
  SubShort(L, R, Result);
end;

class operator TInt128.-(const aValue: TInt128): TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := aValue.FLimbs[0];
  Result.FLimbs[1] := aValue.FLimbs[1] xor SIGN_FLAG;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := aValue.FLimbs[0];
  Result.FLimbs[1] := aValue.FLimbs[1];
  Result.FLimbs[2] := aValue.FLimbs[2];
  Result.FLimbs[3] := aValue.FLimbs[3] xor SIGN_FLAG;
{$ENDIF USE_LIMB64}
end;

class operator  TInt128.*(const L, R: TInt128): TInt128;
begin
  DoMul(@L, @R, @Result);
end;

class operator  TInt128.*(const L: TInt128; R: Integer): TInt128;
begin
  DoMulShort(@L, R, @Result);
end;

class operator TInt128.div(const aValue, aD: TInt128): TInt128;
begin
  DivQ(@aValue, @aD, @Result);
end;

class operator TInt128.mod(const aValue, aD: TInt128): TInt128;
begin
  DivR(@aValue, @aD, @Result);
end;

class operator TInt128.div(const aValue: TInt128; aD: Integer): TInt128;
begin
  DivShortQ(@aValue, aD, @Result);
end;

class operator TInt128.mod(const aValue: TInt128; aD: Integer): Integer;
begin
  Result := DivShortR(@aValue, aD);
end;

class function TInt128.MinValue: TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := High(TLimb);
  Result.FLimbs[1] := High(TLimb);
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := High(TLimb);
  Result.FLimbs[1] := High(TLimb);
  Result.FLimbs[2] := High(TLimb);
  Result.FLimbs[3] := High(TLimb);
{$ENDIF USE_LIMB64}
end;

class function TInt128.MaxValue: TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := High(TLimb);
  Result.FLimbs[1] := SIGN_MASK;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := High(TLimb);
  Result.FLimbs[1] := High(TLimb);
  Result.FLimbs[2] := High(TLimb);
  Result.FLimbs[3] := SIGN_MASK;
{$ENDIF USE_LIMB64}
end;

class procedure TInt128.DivRem(const aValue, aD: TInt128; out aQ, aR: TInt128);
begin
  Divide(@aValue, @aD, @aQ, @aR);
end;

class function TInt128.DivRem(const aValue: TInt128; aD: Integer; out aQ: TInt128): Integer;
begin
  Result := DivShort(@aValue, aD, @aQ);
end;

class function TInt128.Encode(aValue: Int64): TInt128;
begin
  if aValue > 0 then
    begin
{$IFDEF USE_LIMB64}
    Result.FLimbs[0] := TLimb(aValue);
    Result.FLimbs[1] := 0;
{$ELSE USE_LIMB64}
    Result.FLimbs[0] := TLimb(aValue);
    Result.FLimbs[1] := TLimb(aValue shr TUInt128.BIT_PER_LIMB);
    Result.FLimbs[2] := 0;
    Result.FLimbs[3] := 0;
{$ENDIF USE_LIMB64}
    end
  else
    if aValue < 0 then
      begin
{$IFDEF USE_LIMB64}
      Result.FLimbs[0] := -TLimb(aValue);
      Result.FLimbs[1] := SIGN_FLAG;
{$ELSE USE_LIMB64}
      Result.FLimbs[0] := TLimb(-QWord(aValue));
      Result.FLimbs[1] := TLimb((-QWord(aValue)) shr TUInt128.BIT_PER_LIMB);
      Result.FLimbs[2] := 0;
      Result.FLimbs[3] := SIGN_FLAG;
{$ENDIF USE_LIMB64}
      end
    else
      begin
{$IFDEF USE_LIMB64}
        Result.FLimbs[0] := 0;
        Result.FLimbs[1] := 0;
{$ELSE USE_LIMB64}
        Result.FLimbs[0] := 0;
        Result.FLimbs[1] := 0;
        Result.FLimbs[2] := 0;
        Result.FLimbs[3] := 0;
{$ENDIF USE_LIMB64}
      end;
end;

class function TInt128.Encode(aLo, aHi: QWord): TInt128;
begin
  Result := TInt128(TUInt128.Encode(aLo, aHi));
end;

class function TInt128.Encode(v0, v1, v2, v3: DWord): TInt128;
begin
  Result := TInt128(TUInt128.Encode(v0, v1, v2, v3));
end;

class function TInt128.Random: TInt128;
begin
  Result := TInt128(TUInt128.Random);
  Result.HiLimbMacro := Result.HiLimbMacro and SIGN_MASK;
end;

class function TInt128.RandomInRange(const aRange: TInt128): TInt128;
begin
  Result := TInt128(TUInt128.RandomInRange(TUInt128(aRange.AbsValue)));
  if aRange.HiLimbMacro and SIGN_FLAG <> 0 then
    Result.HiLimbMacro := Result.HiLimbMacro or SIGN_FLAG;
end;

class function TInt128.Parse(const s: string): TInt128;
begin
  if not TryParse(s, Result) then
    raise EConvertError.CreateFmt(SInvalidInteger, [s]);
end;

procedure TInt128.Negate;
begin
  HiLimbMacro := HiLimbMacro xor SIGN_FLAG;
end;

class function TInt128.TryParse(const s: string; out aValue: TInt128): Boolean;
var
  IsNeg: Boolean = False;
  sCopy: string;
begin
  if s <> '' then
    begin
    sCopy := s;
    IsNeg := sCopy[1] = '-';
    if IsNeg then
      sCopy := System.Copy(sCopy, 2, System.Length(sCopy));
    if TUInt128.TryParseStr(sCopy, aValue.FLimbs) and (aValue.HiLimbMacro and SIGN_FLAG = 0) then
      begin
        if IsNeg then
          aValue.Negate;
        exit(True);
      end;
    end;
  Result := False;
end;

class function TInt128.Compare(const L, R: TInt128): SizeInt;
begin
  Result := Cmp(L, R);
end;

class function TInt128.Equal(const L, R: TInt128): Boolean;
begin
  Result := L = R;
end;

class function TInt128.HashCode(const aValue: TInt128): SizeInt;
begin
  Result := TxxHash32LE.HashGuid(TGuid(aValue.GetNormLimbs));
end;

function TInt128.Lo: QWord;
begin
  Result := TUInt128(FLimbs).Lo;
end;

function TInt128.Hi: QWord;
begin
  Result := TUInt128(FLimbs).Hi;
end;

function TInt128.IsZero: Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := FLimbs[0] or (FLimbs[1] and SIGN_MASK) = 0;
{$ELSE USE_LIMB64}
  Result := FLimbs[0] or FLimbs[1] or FLimbs[2] or (FLimbs[3] and SIGN_MASK) = 0;
{$ENDIF USE_LIMB64}
end;

procedure TInt128.SetZero;
begin
  FLimbs := Default(TLimbs128);
end;

function TInt128.IsOdd: Boolean;
begin
  Result := Boolean(FLimbs[0] and 1);
end;

function TInt128.IsNegative: Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (FLimbs[0] or (FLimbs[1] and SIGN_MASK) <> 0) and (FLimbs[1] and SIGN_FLAG <> 0);
{$ELSE USE_LIMB64}
  Result := (FLimbs[0] or FLimbs[1] or FLimbs[2] or (FLimbs[3] and SIGN_MASK) <> 0) and
            (FLimbs[3] and SIGN_FLAG <> 0);
{$ENDIF USE_LIMB64}
end;

function TInt128.IsPositive: Boolean;
begin
{$IFDEF USE_LIMB64}
  Result := (FLimbs[0] or (FLimbs[1] and SIGN_MASK) <> 0) and (FLimbs[1] and SIGN_FLAG = 0);
{$ELSE USE_LIMB64}
  Result := (FLimbs[0] or FLimbs[1] or FLimbs[2] or (FLimbs[3] and SIGN_MASK) <> 0) and
            (FLimbs[3] and SIGN_FLAG = 0);
{$ENDIF USE_LIMB64}
end;

function TInt128.Sign: TValueSign;
begin
{$IFDEF USE_LIMB64}
  if FLimbs[0] or (FLimbs[1] and SIGN_MASK) = 0 then
    exit(0);
  if FLimbs[1] and SIGN_FLAG = 0 then
    exit(1);
{$ELSE USE_LIMB64}
  if FLimbs[0] or FLimbs[1] or FLimbs[2] or (FLimbs[3] and SIGN_MASK) = 0 then
    exit(0);
  if FLimbs[3] and SIGN_FLAG = 0 then
    exit(1);
{$ENDIF USE_LIMB64}
  Result := -1;
end;

function TInt128.BitLength: Integer;
begin
  Result := Succ(TUInt128.MsBitIndex(FLimbs));
end;

function TInt128.AbsValue: TInt128;
begin
{$IFDEF USE_LIMB64}
  Result.FLimbs[0] := FLimbs[0];
  Result.FLimbs[1] := FLimbs[1] and SIGN_MASK;
{$ELSE USE_LIMB64}
  Result.FLimbs[0] := FLimbs[0];
  Result.FLimbs[1] := FLimbs[1];
  Result.FLimbs[2] := FLimbs[2];
  Result.FLimbs[3] := FLimbs[3] and SIGN_MASK;
{$ENDIF USE_LIMB64}
end;

function TInt128.ToDouble: Double;
begin
  Result := TUInt128(AbsValue).ToDouble;
  if HiLimbMacro and SIGN_FLAG <> 0 then
    Result := -Result;
end;

function TInt128.ToExtended: Extended;
begin
  Result := TUInt128(AbsValue).ToExtended;
  if HiLimbMacro and SIGN_FLAG <> 0 then
    Result := -Result;
end;

function TInt128.ToString: string;
begin
  if IsZero then
    exit('0');
  Result := TUInt128.Val2Str(AbsValue.FLimbs);
  if Self.HiLimbMacro and SIGN_FLAG <> 0 then
    System.Insert('-', Result, 1);
end;

function TInt128.ToHexString(aMinDigits: Integer; aShowRadix: Boolean): string;
begin
  Result := TUInt128.Val2Hex(GetNormLimbs, aMinDigits, aShowRadix);
end;

function TInt128.ToHexString(aShowRadix: Boolean): string;
begin
  Result := TUInt128.Val2Hex(GetNormLimbs, SizeOf(TInt128) * 2, aShowRadix);
end;

end.

