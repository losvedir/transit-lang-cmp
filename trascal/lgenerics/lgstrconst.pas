{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Common string resources.                                                *
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
unit lgStrConst;

{$mode objfpc}{$H+}

interface

resourcestring

  SEOptionalValueEmpty     = 'No value assigned';
  SECopyInadmissible       = 'Copying inadmissible';
  SEOwnRequired            = 'Ownership required';
  SEArgumentTooBigFmt      = 'Argument of %s is too big(%d)';
  SEArrayTooBigFmt         = 'Array size is too big(%d)';
  SEClassAccessEmptyFmt    = 'Can not access element of empty %s';
  SECantAccessEmpty        = 'Can not access element of empty container';
  SEClassCapacityExceedFmt = '%s maximum capacity exceeded(%d)';
  SECapacityExceedFmt      = 'Maximum capacity exceeded(%d)';
  SECantUpdDuringIterFmt   = 'Can not update %s during enumeration';
  SEArrIndexOutOfBoundsFmt = 'Array index out of bounds(%d)';
  SEClassIdxOutOfBoundsFmt = '%s index out of bounds(%d)';
  SEIndexOutOfBoundsFmt    = 'Index out of bounds(%d)';
  SEKeyNotFound            = 'Key not found';
  SEValueNotFound          = 'Value not found';
  SECantAcceptNegCountFmt  = 'The %s''s TEntry.Count can not accept negative value';
  SECantAcceptNegCount     = 'Can not accept negative TEntry.Count value';
  SECantAcceptNegLen       = 'Can not accept negative length value';
  SEInternalDataInconsist  = 'Internal data inconsistency';
  SEInvalidParamFmt        = 'Invalid parameter "%s" value';
  SEInputShouldAtLeastFmt  = 'Parameter "%s" should be at least %d';
  SEValueAlreadyExist      = 'Value already exists';
  SEKeyAlreadyExist        = 'Key already exists';
  SEResultUnknownFatal     = 'Result is unknown due to fatal exception';
  SEResultUnknownCancel    = 'Result is unknown due to task cancelled';
  SECellNotFoundFmt        = 'Specified cell of %s not found';
  SEEdgeNotFoundFmt        = 'Edge (%d, %d) not found';
  SECallbackMissed         = 'Callback missed';
  SEStreamWriteVertMissed  = 'OnWriteVertex callback missed';
  SEStreamWriteDataMissed  = 'OnWriteData callback missed';
  SEStreamReadVertMissed   = 'OnReadVertex callback missed';
  SEStreamReadDataMissed   = 'OnReadData callback missed';
  SEUnknownGraphStreamFmt  = 'Unknown graph stream format';
  SEUnsuppGraphFmtVersion  = 'Unsupported graph stream format version';
  SEGraphStreamCorrupt     = 'Graph stream data corrupted';
  SEGraphStreamReadIntern  = 'Graph stream read intenal error';
  SEStrLenExceedFmt        = 'Maximum string length exceeded(%d)';
  SEBitMatrixSizeExceedFmt = 'Maximum bit matrix size exceeded(%d)';
  SEUnableOpenFileFmt      = 'Failed to open file "%s"';
  SEUnableOpenFileFmt3     = 'Failed to open file "%s":' + LineEnding + 'exception %s with message "%s"';
  SEUnexpectEol            = 'Unexpected end of line';
  SEStreamSizeExceedFmt    = 'Maximum stream size exceeded(%d)';
  SEMethodNotApplicable    = 'Method is not applicable';
  SEInputMatrixTrivial     = 'Input matrix is trivial';
  SENonSquareInputMatrix   = 'Input matrix is not square';
  SEInputMatrixNegElem     = 'Input matrix contains negative element';
  SEInvalidTreeInst        = 'Invalid tree instance';
  SENoSuchEdgeFmt          = 'No such edge (%d, %d)';
  SEInputIsNotProperPermut = 'Input array is not proper permutation';
  SEVertexNonUnique        = 'Vertex label is not unique';
  SECantConvertFmt         = 'Cannot convert %s to %s';
  SEInvalidJsPtr           = 'Invalid JSON Pointer instance';
  SECantParseJsStr         = 'Cannot parse JSON string';
  SEJsonInstNotObj         = 'Cannot retrieve pair from non-object instance';
  SESortProcNotAssigned    = 'Sorting procedure not assigned';

implementation

end.

