{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some asynchronous primitives.                                           *
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
unit lgAsync;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  Classes, SysUtils, Math,
  lgUtils,
  lgQueue,
  lgVector,
  lgPriorityQueue,
  lgFunction,
  lgStrConst;

type

  TAsyncTaskState = (atsPending, atsExecuting, atsFinished, atsFatal, atsCancelled);

{$PUSH}{$INTERFACES COM}
  IAsyncTask = interface(ITask)
  ['{4122B5EC-40CF-421D-AFB8-23534663C24E}']
    function  GetState: TAsyncTaskState;
    function  Cancel: Boolean;
    procedure WaitFor;
    function  FatalException: Exception;
    property  State: TAsyncTaskState read GetState;
  end;

  generic IGCallable<T> = interface
  ['{EF605AA3-4E0F-4C52-9A75-5068D94ECDAF}']
    function Call: T;
  end;

  generic IGAsyncTask<T> = interface(IAsyncTask)
  ['{29B0A51F-346F-449F-A232-50697E7B5166}']
    function GetResult: T;
    property Result: T read GetResult;
  end;
{$POP}

{$PUSH}{$INTERFACES CORBA}
  IExecutor = interface
  ['{49381C21-82D6-456E-93A2-B8E0DC4B34BA}']
    procedure EnqueueTask(aTask: ITask);
  end;
{$POP}

  { TAsyncTask }
  TAsyncTask = class abstract(TInterfacedObject, ITask, IAsyncTask)
  strict private
    FAwait: PRtlEvent;
    FException: Exception;
    FState: LongInt;
  protected
    function  GetState: TAsyncTaskState; inline;
  { to override in descendants }
    procedure DoExecute; virtual; abstract;
    function  Cancel: Boolean; inline;
    procedure Execute;
    procedure WaitFor;
    function  FatalException: Exception;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  generic TGAsyncTask<T> = class abstract(TAsyncTask, specialize IGAsyncTask<T>)
  protected
    FResult: T; //to be setted inside overriden DoExecute
    function GetResult: T;
    property Result: T read GetResult;
  end;

{
  The futures concept describes an asynchronous single-execution pattern.
  Result is requested at an early stage of execution, but becomes available after it is received.
  This implementation implies that futures are intended for use from the main thread.
}
  { TGFuture: takes over the management of the inner async task }
  generic TGFuture<T> = record
  public
  type
    TOptional = specialize TGOptional<T>;

  private
  type
    IATask   = specialize IGAsyncTask<T>;
    TWorker = class(TThread)
    private
      FTask: IATask;
    protected
      procedure Execute; override;
    public
      constructor Create(aTask: IATask);
    end;

  strict private
    FTask: IATask;
    procedure Resolve;
  private
    function  GetState: TAsyncTaskState; inline;
  { executes aTask in separate thread if aEx = nil }
    procedure Start(aTask: IATask; aEx: IExecutor);
  public
    function  WaitFor: TAsyncTaskState;
    function  Cancel: Boolean; inline;
  { raises exception if resolving failed }
    function  Value: T;
    function  GetValue: TOptional;
    property  State: TAsyncTaskState read GetState;
  end;

  { TGSpawn }

  generic TGSpawn<TFuture, TOpt> = record
  type
    TResults = array of TOpt;
  var
    Futures: array of TFuture;
    procedure WaitFor;
    function  GetResults: TResults;
  end;

  { TGAsyncProc incapsulates method without arguments(which returns void), True indicates execution success }
  TGAsyncProc = class(specialize TGAsyncTask<Boolean>)
  public
  type
    TProcedure      = procedure of object;
    TFuture         = specialize TGFuture<Boolean>;
    TSpawn          = specialize TGSpawn<TFuture, TFuture.TOptional>;
    IProcEnumerable = specialize IGEnumerable<TProcedure>;

  strict private
    FProc: TProcedure;
  protected
    procedure DoExecute; override;
  public
    class function Call(aProc: TProcedure; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of TProcedure; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(e: IProcEnumerable; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aProc: TProcedure);
  end;

  { TAsyncExecutable incapsulates ITask, True indicates execution success }
  TAsyncExecutable = class(specialize TGAsyncTask<Boolean>)
  public
  type
    TFuture         = specialize TGFuture<Boolean>;
    TSpawn          = specialize TGSpawn<TFuture, TFuture.TOptional>;
    ITaskEnumerable = specialize IGEnumerable<ITask>;

  strict private
    FTask: ITask;
  protected
    procedure DoExecute; override;
  public
    class function Run(aTask: ITask; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of ITask; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(e: ITaskEnumerable; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aTask: ITask);
  end;

  { TGAsyncCallable incapsulates IGCallable}
  generic TGAsyncCallable<T> = class(specialize TGAsyncTask<T>)
  public
  type
    ICallable       = specialize IGCallable<T>;
    TFuture         = specialize TGFuture<T>;
    TSpawn          = specialize TGSpawn<TFuture, TFuture.TOptional>;
    ICallEnumerable = specialize IGEnumerable<ICallable>;

  strict private
    FTask: ICallable;
  protected
    procedure DoExecute; override;
  public
    class function Run(aTask: ICallable; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of ICallable; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(e: ICallEnumerable; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aTask: ICallable);
  end;

  { TGAsyncMethod incapsulates niladic method(without arguments which returns T) }
  generic TGAsyncMethod<T> = class(specialize TGAsyncTask<T>)
  public
  type
    TFun           = function: T of object;
    TFuture        = specialize TGFuture<T>;
    TSpawn         = specialize TGSpawn<TFuture, TFuture.TOptional>;
    IFunEnumerable = specialize IGEnumerable<TFun>;

  strict private
    FFun: TFun;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of TFun; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(e: IFunEnumerable; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncNested incapsulates nested niladic function (without arguments) }
  generic TGAsyncNested<T> = class(specialize TGAsyncTask<T>)
  public
  type
    TFun           = function: T is nested;
    TFuture        = specialize TGFuture<T>;
    TSpawn         = specialize TGSpawn<TFuture, TFuture.TOptional>;
    IFunEnumerable = specialize IGEnumerable<TFun>;

  strict private
    FFun: TFun;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of TFun; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncNiladic incapsulates regular niladic function (without arguments) }
  generic TGAsyncNiladic<T> = class(specialize TGAsyncTask<T>)
  public
  type
    TFun           = function: T;
    TFuture        = specialize TGFuture<T>;
    TSpawn         = specialize TGSpawn<TFuture, TFuture.TOptional>;
    IFunEnumerable = specialize IGEnumerable<TFun>;

  strict private
    FFun: TFun;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(const a: array of TFun; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(e: IFunEnumerable; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncMonadic incapsulates regular monadic function (with one argument) }
  generic TGAsyncMonadic<T, TResult> = class(specialize TGAsyncTask<TResult>)
  strict private
  type
    TCall = specialize TGDeferMonadic<T, TResult>;

  public
  type
    TFun             = TCall.TFun;
    TFuture          = specialize TGFuture<TResult>;
    TParamEnumerable = specialize IGEnumerable<T>;
    TSpawn           = specialize TGSpawn<TFuture, TFuture.TOptional>;
    TCallData        = TCall.TCallData;

  strict private
    FCall: TCall;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; const v: T; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(aFun: TFun; const Args: array of T; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(aFun: TFun; e: TParamEnumerable; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(const a: array of TCallData; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun; const v: T);
  end;

  { TGAsyncDyadic incapsulates regular dyadic function (with two arguments) }
  generic TGAsyncDyadic<T1, T2, TResult> = class(specialize TGAsyncTask<TResult>)
  strict private
  type
    TCall = specialize TGDeferDyadic<T1, T2, TResult>;

  public
  type
    TFun           = TCall.TFun;
    TFuture        = specialize TGFuture<TResult>;
    TParamTuple    = TCall.TParamTuple;
    TTupEnumerable = specialize IGEnumerable<TParamTuple>;
    TSpawn         = specialize TGSpawn<TFuture, TFuture.TOptional>;
    TCallData      = TCall.TCallData;

  strict private
    FCall: TCall;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; const v1: T1; const v2: T2; aEx: IExecutor = nil): TFuture;
                   static;
    class function CallTup(aFun: TFun; const aTup: TParamTuple; aEx: IExecutor = nil): TFuture;
                   static;
    class function Spawn(aFun: TFun; const Args: array of TParamTuple;
                   aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(aFun: TFun; e: TTupEnumerable; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(const a: array of TCallData; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun; const v1: T1; const v2: T2);
    constructor Create(aFun: TFun; const aTup: TParamTuple);
  end;

  { TGAsyncTriadic incapsulates regular triadic function (with three arguments) }
  generic TGAsyncTriadic<T1, T2, T3, TResult> = class(specialize TGAsyncTask<TResult>)
  strict private
  type
    TCall = specialize TGDeferTriadic<T1, T2, T3, TResult>;

  public
  type
    TFun           = TCall.TFun;
    TFuture        = specialize TGFuture<TResult>;
    TParamTuple    = TCall.TParamTuple;
    TTupEnumerable = specialize IGEnumerable<TParamTuple>;
    TSpawn         = specialize TGSpawn<TFuture, TFuture.TOptional>;
    TCallData      = TCall.TCallData;

  strict private
    FCall: TCall;
  protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; const v1: T1; const v2: T2; const v3: T3;
                        aEx: IExecutor = nil): TFuture; static;
    class function CallTup(aFun: TFun; const aTup: TParamTuple; aEx: IExecutor = nil): TFuture; static;
    class function Spawn(aFun: TFun; const Args: array of TParamTuple; aEx: IExecutor = nil): TSpawn;
                   static;
    class function Spawn(aFun: TFun; e: TTupEnumerable; aEx: IExecutor = nil): TSpawn; static;
    class function Spawn(const a: array of TCallData; aEx: IExecutor = nil): TSpawn; static;
    constructor Create(aFun: TFun; const v1: T1; const v2: T2; const v3: T3);
    constructor Create(aFun: TFun; const aTup: TParamTuple);
  end;

const
  DEFAULT_POOL_SIZE = 4;

type
  { TDefaultExecutor executes futures in its own thread pool.
    Enqueue procedure is threadsafe, so futures may use other futures.
    Resizing of thread pool is not threadsafe, so MUST be done from main thread. }
  TDefaultExecutor = class
  private
  type
    TTaskQueue = class
    strict private
    type
      TQueue = specialize TGLiteQueue<ITask>;

    var
      FQueue: TQueue;
      FReadAwait: PRtlEvent;
      FLock: TRtlCriticalSection;
      FClosed: Boolean;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      procedure Close;
      procedure Open;
      procedure Enqueue(aTask: ITask);
      function  Dequeue(out aTask: ITask): Boolean;
      function  GetCount: SizeInt; // not syncronized
    end;

    TWorkThread = class(TThread)
    strict private
      FQueue: TTaskQueue;
    public
      constructor Create(aQueue: TTaskQueue);
      procedure Execute; override;
    end;

    TThreadPool = specialize TGLiteVector<TWorkThread>;

    TExecutor = class(TObject, IExecutor)
    private
      FTaskQueue: TTaskQueue;
      FThreadPool: TThreadPool;
      function  ThreadCount: Integer; inline;
      function  AddThread: TWorkThread;
      procedure PoolGrow(aValue: Integer);
      procedure PoolShrink(aValue: Integer);
      procedure TerminatePool;
      procedure FinalizePool; inline;
    public
      constructor Create; overload;
      constructor Create(aThreadCount: Integer); overload;
      destructor  Destroy; override;
      procedure EnqueueTask(aTask: ITask);
      function  Unhandled: SizeInt;
    end;

  class var
    CFExecutor: TExecutor; // CF -> Class Field
    class constructor Init;
    class destructor  Done;
    class function  GetThreadCount: Integer; static; inline;
    class procedure SetThreadCount(aValue: Integer); static;
    class function  GetInstance: IExecutor; static;
  public
  { always returns nil; just to hide the constructor }
    class function  Create: TDefaultExecutor; static;
    class procedure EnsureThreadCount(aValue: Integer); static;
    class procedure Enqueue(aTask: IAsyncTask); static;
  { not syncronized, for estimate purpose only  }
    class function  UnhandledCount: SizeInt; static;
    class property  ThreadCount: Integer read GetThreadCount write SetThreadCount;
    class property  Instance: IExecutor read GetInstance;
  end;

  { TSemObj }
  TSemObj = class
  private
    FLock: TRtlCriticalSection;
    FLimit,
    FCounter: Integer;
    FQueue: specialize TGLiteQueue<PRtlEvent>;
    function  CreateEvent(out e: PRTLEvent): PRTLEvent; inline;
    procedure WaitForThenFree(e: PRTLEvent); inline;
    procedure SignalThenFree(e: PRTLEvent); inline;
    function  GetWaitCount: Integer;
  public
    destructor Destroy; override;
    property  Counter: Integer read FCounter;
    property  Limit: Integer read FLimit;
    property  WaitCount: Integer read GetWaitCount;
  end;

  { TSemaphore }
  TSemaphore = class(TSemObj)
  private
    FInitialCount: Integer;
    function GetUsed: Boolean;
  public
  { sets Counter to aInitialCount, i.e. if aInitialCount = 0 then after creation the semaphore is locked;
    raises EArgumentException if aLimit < 1 or aInitialCount < 0 or aInitialCount > aLimit }
    constructor Create(aLimit: Integer; aInitialCount: Integer = 0);
    procedure WaitFor;
  { returns False immediately if the semaphore is locked }
    function  TryWait: Boolean;
  { returns the value of the increment of the counter }
    function  Post(aCount: Integer = 1): Integer;
    property  Used: Boolean read GetUsed;
    property  InitialCount: Integer read FInitialCount;
  end;

  { TBarrier }
  TBarrier = class(TSemObj)
  public
    constructor Create(aLimit: Integer);
    procedure WaitFor;
    function  Signal: Integer;
  end;


const
  DEFAULT_CHAN_SIZE = 256;
  UNBOUND_CHAN_SIZE = High(SizeInt);

type
{$PUSH}{$INTERFACES CORBA}
  generic IGReadChannel<T> = interface
  ['{5861F2A8-CA8E-4EE7-A66A-AA69B80670A7}']
    function GetActive: Boolean;
  { blocking method }
    function Receive(out aValue: T): Boolean;
  { non blocking method }
    function TryReceive(out aValue: T): Boolean;
    property Active: Boolean read GetActive;
  end;

  generic IGWriteChannel<T> = interface
  ['{2B1861EE-950B-411C-AA22-91D1B9B071A5}']
    function GetActive: Boolean;
  { blocking method }
    function Send(const aValue: T): Boolean;
  { non blocking method }
    function TrySend(const aValue: T): Boolean;
    property Active: Boolean read GetActive;
  end;
{$POP}

  { TGBlockChannel }
  generic TGBlockChannel<T> = class(specialize IGReadChannel<T>, specialize IGWriteChannel<T>)
  strict protected
  type
    IQueue = specialize IGQueue<T>;

  var
    FQueue: IQueue;
    FLock: TRtlCriticalSection;
    FWriteAwait,
    FReadAwait: PRtlEvent;
    FCapacity: SizeInt;
    FWait: Integer;
    FActive: Boolean;
    function  GetWait: Boolean; inline;
    function  GetActive: Boolean; inline;
    function  GetCapacity: SizeInt; inline;
    procedure SendData(const aValue: T);
    function  ReceiveData: T;
    class function CreateQueue(aCapacity: SizeInt): IQueue; virtual;
  public
  { param aCapacity specifies capacity of inner queue;
    if aCapacity <= 0 then an unbound channel will be created }
    constructor Create(aCapacity: SizeInt = DEFAULT_CHAN_SIZE);
    destructor Destroy; override;
  { blocking method }
    function  Send(const aValue: T): Boolean;
  { non blocking method }
    function  TrySend(const aValue: T): Boolean;
  { blocking method }
    function  Receive(out aValue: T): Boolean;
  { non blocking method }
    function  TryReceive(out aValue: T): Boolean;
  { returns the number of messages in the queue, -1 if not active }
    function  PeekCount: SizeInt;
    procedure Close;
    procedure Open;
  { if is not Active then Send and Receive will always return False without blocking }
    property  Active: Boolean read FActive;
  { returns True if some thread is waiting for a message }
    property  WaitSend: Boolean read GetWait;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TGPrioBlockChannel channel with a respect to message priority;
    functor TCmpRel (comparision relation) must provide
      class function Compare([const[ref]] L, R: T): SizeInt }
  generic TGPrioBlockChannel<T, TCmpRel> = class(specialize TGBlockChannel<T>)
  strict protected
    class function CreateQueue(aCapacity: SizeInt): IQueue; override;
  end;

  generic TGBlockPrioChannel<T> = class(specialize TGPrioBlockChannel<T, T>);

  { TGObjBlockChannel }
  generic TGObjBlockChannel<T: class> = class(specialize TGBlockChannel<T>)
  private
  type
    TQueue = specialize TGObjectQueue<T>;

    function  GetOwnsObjects: Boolean; inline;
    procedure SetOwnsObjects(aValue: Boolean); inline;
  strict protected
    class function CreateQueue(aCapacity: SizeInt): IQueue; override;
  public
    constructor Create(aCapacity: SizeInt = DEFAULT_CHAN_SIZE; aOwnsObjects: Boolean = True);
    property OwnsObjects: Boolean read GetOwnsObjects write SetOwnsObjects;
  end;

{$PUSH}{$INTERFACES CORBA}
  IWorkThread = interface
  ['{2C1E3FEF-C538-4506-A0A1-02C0B535B22F}']
    function  GetThreadID: TThreadID;
    function  GetHandle: TThreadID;
    procedure Queue(aMethod: TThreadMethod);
    procedure Synchronize(aMethod: TThreadMethod);
    property  ThreadID: TThreadID read GetThreadID;
    property  Handle: TThreadID read GetHandle;
  end;
{$POP}

  TWorkThread = class(TThread, IWorkThread)
  protected
    function  GetThreadID: TThreadID;
    function  GetHandle: TThreadID;
  end;

  { TGListenThread abstract ancestor class:
    thread that has its own blocking message queue; T is the type of message }
  generic TGListenThread<T> = class abstract
  strict private
  type
    TChannel  = specialize TGBlockChannel<T>;
    IReadChan = specialize IGReadChannel<T>;

    TWorker = class(TWorkThread)
    private
      FChannel: IReadChan;
      FOwner: TGListenThread;
    protected
      procedure Execute; override;
    public
      constructor Create(aOwner: TGListenThread; aChannel: IReadChan; aStackSize: SizeUInt);
    end;

  var
    FChannel: TChannel;
    FWorker: TWorker;
    function  GetCapacity: SizeInt;
    function  GetEnqueued: SizeInt;
    function  GetPriority: TThreadPriority;
    procedure SetPriority(aValue: TThreadPriority);
    function  GetThreadID: TThreadID;
    function  GetHandle: TThreadID;
  protected
  { by default do nothing }
    procedure HandleException(const aMsg: T; aThreed: IWorkThread; e: Exception); virtual;
  { to be overriden in descendants }
    procedure HandleMessage(const aMessage: T; aThread: IWorkThread); virtual; abstract;
    class function CreateChannel(aCapacity: SizeInt): TChannel; virtual;
  public
  { the creation/destruction is not thread-save;
    param aCapacity specifies capacity of inner queue;
    if aCapacity <= 0 then an unbound inner queue will be created }
    constructor Create(aCapacity: SizeInt = DEFAULT_CHAN_SIZE; aStackSize: SizeUInt = DefaultStackSize);
    destructor Destroy; override;
    procedure AfterConstruction; override;
  { blocking method }
    procedure Send(const aMessage: T); inline;
  { non blocking method }
    function  TrySend(const aMessage: T): Boolean; inline;
    property  Priority: TThreadPriority read GetPriority write SetPriority;
    property  ThreadID: TThreadID read GetThreadID;
    property  Handle: TThreadID read GetHandle;
  { returns the number of messages in the inner queue }
    property  Enqueued: SizeInt read GetEnqueued;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TThreadPool }
  TThreadPool = class(TObject, IExecutor)
  strict private
  type
    TChannel  = specialize TGBlockChannel<ITask>;
    IReadChan = specialize IGReadChannel<ITask>;

    TWorker = class(TWorkThread)
    private
      FChannel: IReadChan;
      FOwner: TThreadPool;
    protected
      procedure Execute; override;
    public
      constructor Create(aOwner: TThreadPool; aChannel: IReadChan; aStackSize: SizeUInt);
    end;

    TPool = specialize TGLiteVector<TWorker>;

  var
    FChannel: TChannel;
    FPool: TPool;
    FStackSize: SizeInt;
    FLock: TRtlCriticalSection;
    function  GetCapacity: SizeInt;
    function  GetEnqueued: SizeInt;
    function  GetThreadCount: SizeInt;
    procedure SetThreadCount(aValue: SizeInt);
    procedure AddThread;
    procedure PoolGrow(aValue: SizeInt);
    procedure PoolShrink(aValue: SizeInt);
    procedure TerminatePool;
  protected
    procedure Lock; inline;
    procedure Unlock; inline;
  { by default do nothing }
    procedure HandleException(aThreed: IWorkThread; e: Exception); virtual;
  public
  { the creation is not thread-save;
    if aQueueCapacity <= 0 then an unbound inner queue will be created }
    constructor Create(aThreadCount: SizeInt = 0; aQueueCapacity: SizeInt = DEFAULT_CHAN_SIZE;
                       aThreadStackSize: SizeUInt = DefaultStackSize);
    destructor Destroy; override;
    procedure EnsureThreadCount(aValue: SizeInt);
  { blocking method }
    procedure EnqueueTask(aTask: ITask);
  { non blocking method }
    function  TryEnqueueTask(aTask: ITask): Boolean;
    property  ThreadCount: SizeInt read GetThreadCount write SetThreadCount;
  { returns the number of tasks in the inner queue; for estimate purpose only }
    property  Enqueued: SizeInt read GetEnqueued;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TPrioThreadPool: simple thread pool with a respect to priority of the task }
  TPrioThreadPool = class
  private
  type
    TChannel = specialize TGBlockPrioChannel<IPriorityTask>;

    TWorker = class(TWorkThread)
    private
      FChannel: TChannel;
      FOwner: TPrioThreadPool;
    protected
      procedure Execute; override;
    public
      constructor Create(aOwner: TPrioThreadPool; aChannel: TChannel; aStackSize: SizeUInt);
    end;

    TPool = specialize TGLiteVector<TWorker>;

  var
    FChannel: TChannel;
    FPool: TPool;
    FStackSize: SizeInt;
    FLock: TRtlCriticalSection;
    function  GetCapacity: SizeInt;
    function  GetEnqueued: SizeInt;
    function  GetThreadCount: SizeInt;
    procedure SetThreadCount(aValue: SizeInt);
    procedure AddThread;
    procedure PoolGrow(aValue: SizeInt);
    procedure PoolShrink(aValue: SizeInt);
    procedure TerminatePool;
  protected
    procedure Lock; inline;
    procedure Unlock; inline;
  { by default do nothing }
    procedure HandleException(aThreed: IWorkThread; e: Exception); virtual;
  public
  { the creation is not thread-save;
    if aQueueCapacity <= 0 then an unbound inner queue will be created }
    constructor Create(aThreadCount: SizeInt = 0; aQueueCapacity: SizeInt = DEFAULT_CHAN_SIZE;
                       aThreadStackSize: SizeUInt = DefaultStackSize);
    destructor Destroy; override;
    procedure EnsureThreadCount(aValue: SizeInt);
  { blocking method }
    procedure EnqueueTask(aTask: IPriorityTask);
  { non blocking method }
    function  TryEnqueueTask(aTask: IPriorityTask): Boolean;
    property  ThreadCount: SizeInt read GetThreadCount write SetThreadCount;
  { returns the number of tasks in the inner queue; for estimate purpose only }
    property  Enqueued: SizeInt read GetEnqueued;
    property  Capacity: SizeInt read GetCapacity;
  end;

  TTaskExceptionHandler = procedure(aId: TThreadID; e: Exception) of object;

  procedure ExecuteTask(aTask: ITask; aHandler: TTaskExceptionHandler = nil);
  function  DefaultExecutor: IExecutor; inline;

implementation
{$B-}{$COPERATORS ON}

type

  { TTaskWorker }
  TTaskWorker = class(TThread)
  private
    FTask: ITask;
    FHandler: TTaskExceptionHandler;
  protected
    procedure Execute; override;
  public
    constructor Create(aTask: ITask; aHandler: TTaskExceptionHandler);
  end;

{ TTaskWorker }

procedure TTaskWorker.Execute;
begin
  if FTask <> nil then
    try
      FTask.Execute;
    except
      if FHandler <> nil then
        FHandler(ThreadID, Exception(System.AcquireExceptionObject))
    end;
  Terminate;
end;

constructor TTaskWorker.Create(aTask: ITask; aHandler: TTaskExceptionHandler);
begin
  inherited Create(True);
  FTask := aTask;
  FHandler := aHandler;
  FreeOnTerminate := True;
end;

procedure ExecuteTask(aTask: ITask; aHandler: TTaskExceptionHandler);
begin
  with TTaskWorker.Create(aTask, aHandler) do
    Start;
end;

function DefaultExecutor: IExecutor;
begin
  Result := TDefaultExecutor.Instance;
end;

{ TAsyncTask }

function TAsyncTask.GetState: TAsyncTaskState;
begin
  Result := TAsyncTaskState(FState);
end;

function TAsyncTask.Cancel: Boolean;
begin
  Result :=
    InterlockedCompareExchange(FState, LongInt(atsCancelled), LongInt(atsPending)) = LongInt(atsPending);
end;

procedure TAsyncTask.Execute;
begin
  if InterlockedCompareExchange(
       FState, LongInt(atsExecuting), LongInt(atsPending)) = LongInt(atsPending) then
    try
      DoExecute;
      InterlockedIncrement(FState);
    except
      on e: Exception do
        begin
          InterlockedExchange(FState, LongInt(atsFatal));
          FException := Exception(System.AcquireExceptionObject);
        end;
    end;
  System.RtlEventSetEvent(FAwait);
end;

procedure TAsyncTask.WaitFor;
begin
  System.RtlEventWaitFor(FAwait);
  System.RtlEventSetEvent(FAwait);
end;

function TAsyncTask.FatalException: Exception;
begin
  Result := FException;
  FException := nil;
end;

constructor TAsyncTask.Create;
begin
  FAwait := System.RtlEventCreate;
end;

destructor TAsyncTask.Destroy;
begin
  System.RtlEventDestroy(FAwait);
  FAwait := nil;
  FException.Free;
  inherited;
end;

{ TGAsyncTask }

function TGAsyncTask.GetResult: T;
begin
  Result := FResult;
end;

{ TGFuture.TWorker }

procedure TGFuture.TWorker.Execute;
begin
  if FTask <> nil then
    FTask.Execute;
  Terminate;
end;

constructor TGFuture.TWorker.Create(aTask: IATask);
begin
  inherited Create(True);
  FTask := aTask;
  FreeOnTerminate := True;
end;

{ TGFuture }

procedure TGFuture.Resolve;
var
  e: Exception;
begin
  FTask.WaitFor;
  if FTask.State = atsFatal then
    begin
      e := FTask.FatalException;
      if e <> nil then
        raise e;
    end;
end;

function TGFuture.GetState: TAsyncTaskState;
begin
  Result := FTask.State;
end;

procedure TGFuture.Start(aTask: IATask; aEx: IExecutor);
begin
  FTask := aTask;
  if aEx <> nil then
    aEx.EnqueueTask(FTask)
  else
    with TWorker.Create(aTask) do
      Start;
end;

function TGFuture.WaitFor: TAsyncTaskState;
begin
  try
    Resolve;
  except
  end;
  Result := FTask.State;
end;

function TGFuture.Cancel: Boolean;
begin
  Result := FTask.Cancel;
end;

function TGFuture.Value: T;
begin
  Resolve;
  case FTask.State of
    atsFatal:
      raise ELGFuture.Create(SEResultUnknownFatal);
    atsCancelled:
      raise ELGFuture.Create(SEResultUnknownCancel);
  else
  end;
  Result := FTask.Result;
end;

function TGFuture.GetValue: TOptional;
begin
  if WaitFor < atsFatal then
    Result.Assign(FTask.Result);
end;

{ TGSpawn }

procedure TGSpawn.WaitFor;
var
  I: SizeInt;
begin
  for I := 0 to Pred(System.Length(Futures)) do
    Futures[I].WaitFor;
end;

function TGSpawn.GetResults: TResults;
var
  I: SizeInt;
begin
  System.SetLength(Result, System.Length(Futures));
  for I := 0 to Pred(System.Length(Futures)) do
    Result[I] := Futures[I].GetValue;
end;

{ TGAsyncProc }

procedure TGAsyncProc.DoExecute;
begin
  FResult := False;
  FProc();
  FResult := True;
end;

class function TGAsyncProc.Call(aProc: TProcedure; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncProc.Create(aProc), aEx);
end;

class function TGAsyncProc.Spawn(const a: array of TProcedure; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Call(a[I], aEx);
end;

class function TGAsyncProc.Spawn(e: IProcEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  Proc: TProcedure;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for Proc in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Call(Proc, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

constructor TGAsyncProc.Create(aProc: TProcedure);
begin
  inherited Create;
  FProc := aProc;
end;

{ TAsyncExecutable }

procedure TAsyncExecutable.DoExecute;
begin
  FResult := False;
  FTask.Execute;
  FResult := True;
end;

class function TAsyncExecutable.Run(aTask: ITask; aEx: IExecutor): TFuture;
begin
  Result.Start(TAsyncExecutable.Create(aTask), aEx);
end;

class function TAsyncExecutable.Spawn(const a: array of ITask; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Run(a[I], aEx);
end;

class function TAsyncExecutable.Spawn(e: ITaskEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  Task: ITask;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for Task in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Run(Task, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

constructor TAsyncExecutable.Create(aTask: ITask);
begin
  inherited Create;
  FTask := aTask;
end;

{ TGAsyncCallable }

procedure TGAsyncCallable.DoExecute;
begin
  FResult := FTask.Call;
end;

class function TGAsyncCallable.Run(aTask: ICallable; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncCallable.Create(aTask), aEx);
end;

class function TGAsyncCallable.Spawn(const a: array of ICallable; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Run(a[I], aEx);
end;

class function TGAsyncCallable.Spawn(e: ICallEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  Call: ICallable;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for Call in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Run(Call, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

constructor TGAsyncCallable.Create(aTask: ICallable);
begin
  inherited Create;
  FTask := aTask;
end;

{ TGAsyncMethod }

procedure TGAsyncMethod.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncMethod.Call(aFun: TFun; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncMethod.Create(aFun), aEx);
end;

class function TGAsyncMethod.Spawn(const a: array of TFun; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Call(a[I], aEx);
end;

class function TGAsyncMethod.Spawn(e: IFunEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  f: TFun;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for f in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Call(f, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

constructor TGAsyncMethod.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncNested }

procedure TGAsyncNested.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncNested.Call(aFun: TFun; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncNested.Create(aFun), aEx);
end;

class function TGAsyncNested.Spawn(const a: array of TFun; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Call(a[I], aEx);
end;

constructor TGAsyncNested.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncNiladic }

procedure TGAsyncNiladic.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncNiladic.Call(aFun: TFun; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncNiladic.Create(aFun), aEx);
end;

class function TGAsyncNiladic.Spawn(const a: array of TFun; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Call(a[I], aEx);
end;

class function TGAsyncNiladic.Spawn(e: IFunEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  f: TFun;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for f in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Call(f, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

constructor TGAsyncNiladic.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncMonadic }

procedure TGAsyncMonadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncMonadic.Call(aFun: TFun; const v: T; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncMonadic.Create(aFun, v), aEx);
end;

class function TGAsyncMonadic.Spawn(aFun: TFun; const Args: array of T; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(Args));
  for I := 0 to Pred(System.Length(Args)) do
    Result.Futures[I] := Call(aFun, Args[I], aEx);
end;

class function TGAsyncMonadic.Spawn(aFun: TFun; e: TParamEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  v: T;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for v in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := Call(aFun, v, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

class function TGAsyncMonadic.Spawn(const a: array of TCallData; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := Call(a[I].F1, a[I].F2, aEx);
end;

constructor TGAsyncMonadic.Create(aFun: TFun; const v: T);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v);
end;

{ TGAsyncDyadic }

procedure TGAsyncDyadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncDyadic.Call(aFun: TFun; const v1: T1; const v2: T2; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncDyadic.Create(aFun, v1, v2), aEx);
end;

class function TGAsyncDyadic.CallTup(aFun: TFun; const aTup: TParamTuple; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncDyadic.Create(aFun, aTup), aEx);
end;

class function TGAsyncDyadic.Spawn(aFun: TFun; const Args: array of TParamTuple; aEx: IExecutor
  ): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(Args));
  for I := 0 to Pred(System.Length(Args)) do
    Result.Futures[I] := CallTup(aFun, Args[I], aEx);
end;

class function TGAsyncDyadic.Spawn(aFun: TFun; e: TTupEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  Tup: TParamTuple;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for Tup in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := CallTup(aFun, Tup, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

class function TGAsyncDyadic.Spawn(const a: array of TCallData; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := CallTup(a[I].F1, a[I].F2, aEx);
end;

constructor TGAsyncDyadic.Create(aFun: TFun; const v1: T1; const v2: T2);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v1, v2);
end;

constructor TGAsyncDyadic.Create(aFun: TFun; const aTup: TParamTuple);
begin
  inherited Create;
  FCall := TCall.Create(aFun, aTup);
end;

{ TGAsyncTriadic }

procedure TGAsyncTriadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncTriadic.Call(aFun: TFun; const v1: T1; const v2: T2; const v3: T3;
  aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncTriadic.Create(aFun, v1, v2, v3), aEx);
end;

class function TGAsyncTriadic.CallTup(aFun: TFun; const aTup: TParamTuple; aEx: IExecutor): TFuture;
begin
  Result.Start(TGAsyncTriadic.Create(aFun, aTup), aEx);
end;

class function TGAsyncTriadic.Spawn(aFun: TFun; const Args: array of TParamTuple;
  aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(Args));
  for I := 0 to Pred(System.Length(Args)) do
    Result.Futures[I] := CallTup(aFun, Args[I], aEx);
end;

class function TGAsyncTriadic.Spawn(aFun: TFun; e: TTupEnumerable; aEx: IExecutor): TSpawn;
var
  I: SizeInt = 0;
  Tup: TParamTuple;
begin
  System.SetLength(Result.Futures, ARRAY_INITIAL_SIZE);
  for Tup in e do
    begin
      if I = System.Length(Result.Futures) then
        System.SetLength(Result.Futures, I * 2);
      Result.Futures[I] := CallTup(aFun, Tup, aEx);
      Inc(I);
    end;
  System.SetLength(Result.Futures, I);
end;

class function TGAsyncTriadic.Spawn(const a: array of TCallData; aEx: IExecutor): TSpawn;
var
  I: SizeInt;
begin
  System.SetLength(Result.Futures, System.Length(a));
  for I := 0 to Pred(System.Length(a)) do
    Result.Futures[I] := CallTup(a[I].F1, a[I].F2, aEx);
end;

constructor TGAsyncTriadic.Create(aFun: TFun; const v1: T1; const v2: T2; const v3: T3);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v1, v2, v3);
end;

constructor TGAsyncTriadic.Create(aFun: TFun; const aTup: TParamTuple);
begin
  inherited Create;
  FCall := TCall.Create(aFun, aTup);
end;

{ TDefaultExecutor.TTaskQueue }

constructor TDefaultExecutor.TTaskQueue.Create;
begin
  inherited;
  FReadAwait := System.RtlEventCreate;
  System.InitCriticalSection(FLock);
end;

destructor TDefaultExecutor.TTaskQueue.Destroy;
begin
  System.EnterCriticalSection(FLock);
  try
    Finalize(FQueue);
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Clear;
begin
  System.EnterCriticalSection(FLock);
  try
    FQueue.Clear;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Close;
begin
  System.EnterCriticalSection(FLock);
  try
    FClosed := True;
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Open;
begin
  System.EnterCriticalSection(FLock);
  try
    FClosed := False;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Enqueue(aTask: ITask);
begin
  System.EnterCriticalSection(FLock);
  try
    FQueue.Enqueue(aTask);
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TDefaultExecutor.TTaskQueue.Dequeue(out aTask: ITask): Boolean;
begin
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    if not FClosed then
      begin
        Result := FQueue.TryDequeue(aTask);
        if FQueue.NonEmpty then
         System.RtlEventSetEvent(FReadAwait);
      end
    else
      begin
        Result := False;
        System.RtlEventSetEvent(FReadAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TDefaultExecutor.TTaskQueue.GetCount: SizeInt;
begin
  Result := FQueue.Count;
end;

{ TDefaultExecutor.TWorkThread }

constructor TDefaultExecutor.TWorkThread.Create(aQueue: TTaskQueue);
begin
  inherited Create(True);
  FQueue := aQueue;
end;

procedure TDefaultExecutor.TWorkThread.Execute;
var
  CurrTask: ITask = nil;
begin
  while not Terminated do
    if FQueue.Dequeue(CurrTask) then
      CurrTask.Execute;
end;

{ TDefaultExecutor.TExecutor }

function TDefaultExecutor.TExecutor.ThreadCount: Integer;
begin
  Result := FThreadPool.Count;
end;

function TDefaultExecutor.TExecutor.AddThread: TWorkThread;
begin
  Result := TWorkThread.Create(FTaskQueue);
  FThreadPool.Add(Result);
  Result.Start;
end;

procedure TDefaultExecutor.TExecutor.PoolGrow(aValue: Integer);
begin
  while FThreadPool.Count < aValue do
    AddThread;
end;

procedure TDefaultExecutor.TExecutor.PoolShrink(aValue: Integer);
begin
  if aValue < 1 then
    aValue := 1;
  TerminatePool;
  FTaskQueue.Open;
  PoolGrow(aValue);
end;

procedure TDefaultExecutor.TExecutor.TerminatePool;
var
  CurrThread: TWorkThread;
begin
  for CurrThread in FThreadPool.Reverse do
    CurrThread.Terminate;
  FTaskQueue.Close;
  while FThreadPool.Count > 0 do
    begin
      CurrThread := FThreadPool.Extract(Pred(FThreadPool.Count));
      CurrThread.WaitFor;
      CurrThread.Free;
    end;
end;

procedure TDefaultExecutor.TExecutor.FinalizePool;
begin
  TerminatePool;
  FThreadPool.Clear;
end;

constructor TDefaultExecutor.TExecutor.Create;
begin
  if TThread.ProcessorCount > DEFAULT_POOL_SIZE then
    Create(TThread.ProcessorCount)
  else
    Create(DEFAULT_POOL_SIZE);
end;

constructor TDefaultExecutor.TExecutor.Create(aThreadCount: Integer);
begin
  FTaskQueue := TTaskQueue.Create;
  if aThreadCount > 0 then
    PoolGrow(aThreadCount)
  else
    PoolGrow(1);
end;

destructor TDefaultExecutor.TExecutor.Destroy;
begin
  FTaskQueue.Clear;
  FinalizePool;
  FTaskQueue.Free;
  inherited;
end;

procedure TDefaultExecutor.TExecutor.EnqueueTask(aTask: ITask);
begin
  FTaskQueue.Enqueue(aTask);
end;

function TDefaultExecutor.TExecutor.Unhandled: SizeInt;
begin
  Result := FTaskQueue.GetCount;
end;

{ TDefaultExecutor }

class constructor TDefaultExecutor.Init;
begin
  CFExecutor := nil;
end;

class destructor TDefaultExecutor.Done;
begin
  FreeAndNil(CFExecutor);
end;

class function TDefaultExecutor.GetThreadCount: Integer;
begin
  if Assigned(CFExecutor) then
    Result := CFExecutor.ThreadCount
  else
    Result := 0;
end;

class procedure TDefaultExecutor.SetThreadCount(aValue: Integer);
var
  CurrCount: Integer;
begin
  CurrCount := ThreadCount;
  if aValue > CurrCount then
    EnsureThreadCount(aValue)
  else
    if (aValue > 0) and (aValue < CurrCount) then
      CFExecutor.PoolShrink(aValue);
end;

class function TDefaultExecutor.GetInstance: IExecutor;
begin
  if not Assigned(CFExecutor) then
    CFExecutor := TExecutor.Create;
  Result := CFExecutor;
end;

class function TDefaultExecutor.Create: TDefaultExecutor;
begin
  Result := nil;
end;

class procedure TDefaultExecutor.EnsureThreadCount(aValue: Integer);
begin
  if aValue > ThreadCount then
    if not Assigned(CFExecutor) then
      CFExecutor := TExecutor.Create(aValue)
    else
      CFExecutor.PoolGrow(aValue);
end;

class procedure TDefaultExecutor.Enqueue(aTask: IAsyncTask);
begin
  if not Assigned(CFExecutor) then
    CFExecutor := TExecutor.Create;
  CFExecutor.EnqueueTask(aTask);
end;

class function TDefaultExecutor.UnhandledCount: SizeInt;
begin
  if Assigned(CFExecutor) then
    Result := CFExecutor.Unhandled
  else
    Result := 0;
end;

{ TSemObj }

function TSemObj.CreateEvent(out e: PRTLEvent): PRTLEvent;
begin
  e := System.RTLEventCreate;
  Result := e;
end;

procedure TSemObj.WaitForThenFree(e: PRTLEvent);
begin
  System.RTLeventWaitFor(e);
  System.RTLEventDestroy(e);
end;

procedure TSemObj.SignalThenFree(e: PRTLEvent);
begin
  System.RTLEventSetEvent(e);
  System.RTLEventDestroy(e);
end;

function TSemObj.GetWaitCount: Integer;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := Math.Max(-Counter, 0);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

destructor TSemObj.Destroy;
begin
  System.DoneCriticalSection(FLock);
  while FQueue.NonEmpty do
    SignalThenFree(FQueue.Dequeue);
  inherited;
end;

{ TSemaphore }

function TSemaphore.GetUsed: Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := Counter <> InitialCount;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

constructor TSemaphore.Create(aLimit: Integer; aInitialCount: Integer);
begin
  if aLimit < 1 then
    raise EArgumentException.CreateFmt(SEInputShouldAtLeastFmt, ['aLimit', 1]);
  if (aInitialCount < 0) or (aInitialCount > aLimit) then
    raise EArgumentException.CreateFmt(SEInvalidParamFmt, ['aInitialCount']);
  FLimit := aLimit;
  FInitialCount := aInitialCount;
  FCounter := aInitialCount;
  FQueue.EnsureCapacity(DEFAULT_CONTAINER_CAPACITY);
  System.InitCriticalSection(FLock);
end;

procedure TSemaphore.WaitFor;
var
  e: PRTLEvent;
  MustWait: Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    Dec(FCounter);
    MustWait := Counter < 0;
    if MustWait then
      FQueue.Enqueue(CreateEvent(e));
  finally
    System.LeaveCriticalSection(FLock);
  end;
  if MustWait then
    WaitForThenFree(e);
end;

function TSemaphore.TryWait: Boolean;
begin
  if System.TryEnterCriticalSection(FLock) = 0 then exit(False);
  try
    if Counter < 1 then exit(False);
    Dec(FCounter);
    Result := True;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TSemaphore.Post(aCount: Integer): Integer;
var
  I: Integer;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := Math.Max(Math.Min(aCount, Limit - Counter), 0);
    if Result = 0 then exit;
    for I := 1 to Math.Min(aCount, FQueue.Count) do
      System.RTLEventSetEvent(FQueue.Dequeue);
    FCounter += Result;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TBarrier }

constructor TBarrier.Create(aLimit: Integer);
begin
  if aLimit < 2 then
    raise EArgumentException.CreateFmt(SEInputShouldAtLeastFmt, ['aLimit', 2]);
  FLimit := aLimit;
  FQueue.EnsureCapacity(aLimit);
  System.InitCriticalSection(FLock);
end;

procedure TBarrier.WaitFor;
var
  e: PRTLEvent;
  MustWait: Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    MustWait := Counter < Limit - 1;
    if MustWait then
      begin
        Inc(FCounter);
        FQueue.Enqueue(CreateEvent(e));
      end
    else
      begin
        while FQueue.TryDequeue(e) do
          System.RTLEventSetEvent(e);
        FCounter := 0;
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
  if MustWait then
    WaitForThenFree(e);
end;

function TBarrier.Signal: Integer;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FCounter;
    while FQueue.NonEmpty do
      SignalThenFree(FQueue.Dequeue);
    FCounter := 0;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TGBlockChannel }

function TGBlockChannel.GetWait: Boolean;
begin
  Result := LongBool(FWait);
end;

function TGBlockChannel.GetActive: Boolean;
begin
  Result := FActive;
end;

function TGBlockChannel.GetCapacity: SizeInt;
begin
  Result := FCapacity;
end;

procedure TGBlockChannel.SendData(const aValue: T);
begin
  FQueue.Enqueue(aValue);
  System.RtlEventSetEvent(FReadAwait);
  if FQueue.Count < Capacity then
    System.RtlEventSetEvent(FWriteAwait);
end;

function TGBlockChannel.ReceiveData: T;
begin
  Result := FQueue.Dequeue;
  System.RtlEventSetEvent(FWriteAwait);
  if FQueue.Count > 0 then
    System.RtlEventSetEvent(FReadAwait);
end;

class function TGBlockChannel.CreateQueue(aCapacity: SizeInt): IQueue;
begin
  Result := specialize TGQueue<T>.Create(aCapacity);
end;

constructor TGBlockChannel.Create(aCapacity: SizeInt);
begin
  if aCapacity <= 0 then
    begin
      FQueue := CreateQueue(DEFAULT_CONTAINER_CAPACITY);
      FCapacity := UNBOUND_CHAN_SIZE;
    end
  else
    begin
      FCapacity := aCapacity;
      FQueue := CreateQueue(aCapacity);
    end;
  FActive := True;
  FWriteAwait := System.RtlEventCreate;
  FReadAwait  := System.RtlEventCreate;
  System.RtlEventSetEvent(FWriteAwait);
  System.InitCriticalSection(FLock);
end;

destructor TGBlockChannel.Destroy;
begin
  Close;
  System.EnterCriticalSection(FLock);
  try
    FQueue._GetRef.Free;
    System.RtlEventDestroy(FWriteAwait);
    FWriteAwait := nil;
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

function TGBlockChannel.Send(const aValue: T): Boolean;
begin
  System.RtlEventWaitFor(FWriteAwait);
  System.EnterCriticalSection(FLock);
  try
    Result := False;
    if Active then
      if FQueue.Count < Capacity then
        begin
          SendData(aValue);
          Result := True;
        end else
    else
      System.RtlEventSetEvent(FWriteAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGBlockChannel.TrySend(const aValue: T): Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := False;
    if Active and (FQueue.Count < Capacity) then
      begin
        SendData(aValue);
        Result := True;
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGBlockChannel.Receive(out aValue: T): Boolean;
begin
  InterlockedIncrement(FWait);
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    InterlockedDecrement(FWait);
    Result := False;
    if Active then
      if FQueue.NonEmpty then
        begin
          aValue := ReceiveData;
          Result := True;
        end else
    else
      System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGBlockChannel.TryReceive(out aValue: T): Boolean;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := False;
    if Active and FQueue.NonEmpty then
      begin
        aValue := ReceiveData;
        Result := True;
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGBlockChannel.PeekCount: SizeInt;
begin
  System.EnterCriticalSection(FLock);
  try
    if Active then
      Result := FQueue.Count
    else
      Result := NULL_INDEX;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TGBlockChannel.Close;
begin
  System.EnterCriticalSection(FLock);
  try
    if Active then
      begin
        FActive := False;
        System.RtlEventSetEvent(FReadAwait);
        System.RtlEventSetEvent(FWriteAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TGBlockChannel.Open;
begin
  System.EnterCriticalSection(FLock);
  try
    if not Active then
      begin
        FActive := True;
        if FQueue.Count > 0 then
          System.RtlEventSetEvent(FReadAwait);
        if FQueue.Count < Capacity then
          System.RtlEventSetEvent(FWriteAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TGPrioBlockChannel }

class function TGPrioBlockChannel.CreateQueue(aCapacity: SizeInt): IQueue;
begin
  Result := specialize TGBaseBinHeap<T, TCmpRel>.Create(aCapacity);
end;

{ TGObjBlockChannel }

function TGObjBlockChannel.GetOwnsObjects: Boolean;
begin
  Result := TQueue(FQueue._GetRef).OwnsObjects;
end;

procedure TGObjBlockChannel.SetOwnsObjects(aValue: Boolean);
begin
  TQueue(FQueue._GetRef).OwnsObjects := aValue;
end;

class function TGObjBlockChannel.CreateQueue(aCapacity: SizeInt): IQueue;
begin
  Result := TQueue.Create(aCapacity);
end;

constructor TGObjBlockChannel.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  OwnsObjects := aOwnsObjects;
end;

{ TWorkThread }

function TWorkThread.GetThreadID: TThreadID;
begin
  Result := ThreadID;
end;

function TWorkThread.GetHandle: TThreadID;
begin
  Result := Handle;
end;

{ TGListenThread.TWorker }

procedure TGListenThread.TWorker.Execute;
var
  Message: T;
begin
  while not Terminated and FChannel.Receive(Message) do
    try
      FOwner.HandleMessage(Message, Self);
    except
      FOwner.HandleException(Message, Self, Exception(System.AcquireExceptionObject));
    end;
end;

constructor TGListenThread.TWorker.Create(aOwner: TGListenThread; aChannel: IReadChan; aStackSize: SizeUInt);
begin
  inherited Create(True, aStackSize);
  FOwner := aOwner;
  FChannel := aChannel;
end;


{ TGListenThread }

function TGListenThread.GetCapacity: SizeInt;
begin
  Result := FChannel.Capacity;
end;

function TGListenThread.GetEnqueued: SizeInt;
begin
  Result := FChannel.PeekCount;
end;

function TGListenThread.GetPriority: TThreadPriority;
begin
  Result := tpIdle;
  if FWorker <> nil then
    Result := FWorker.Priority;
end;

procedure TGListenThread.SetPriority(aValue: TThreadPriority);
begin
  if FWorker <> nil then
    FWorker.Priority := aValue;
end;

function TGListenThread.GetThreadID: TThreadID;
begin
  Result := 0;
  if FWorker <> nil then
    Result := FWorker.ThreadID;
end;

function TGListenThread.GetHandle: TThreadID;
begin
  Result := 0;
  if FWorker <> nil then
    Result := FWorker.Handle;
end;

procedure TGListenThread.HandleException(const aMsg: T; aThreed: IWorkThread; e: Exception);
begin
  ReleaseExceptionObject;
end;

class function TGListenThread.CreateChannel(aCapacity: SizeInt): TChannel;
begin
  Result := TChannel.Create(aCapacity);
end;

constructor TGListenThread.Create(aCapacity: SizeInt; aStackSize: SizeUInt);
begin
  FChannel := CreateChannel(aCapacity);
  FWorker := TWorker.Create(Self, FChannel, aStackSize);
end;

destructor TGListenThread.Destroy;
begin
  FWorker.Terminate;
  FChannel.Close;
  FWorker.WaitFor;
  FWorker.Free;
  FChannel.Free;
  inherited;
end;

procedure TGListenThread.AfterConstruction;
begin
  inherited;
  FWorker.Start;
end;

procedure TGListenThread.Send(const aMessage: T);
begin
  FChannel.Send(aMessage);
end;

function TGListenThread.TrySend(const aMessage: T): Boolean;
begin
  Result := FChannel.TrySend(aMessage);
end;

{ TThreadPool.TWorker }

procedure TThreadPool.TWorker.Execute;
var
  CurrTask: ITask = nil;
begin
  while not Terminated and FChannel.Receive(CurrTask) do
    try
      CurrTask.Execute;
    except
      FOwner.HandleException(Self, Exception(System.AcquireExceptionObject));
    end;
end;

constructor TThreadPool.TWorker.Create(aOwner: TThreadPool; aChannel: IReadChan; aStackSize: SizeUInt);
begin
  inherited Create(True, aStackSize);
  FOwner := aOwner;
  FChannel := aChannel;
end;

{ TThreadPool }

function TThreadPool.GetCapacity: SizeInt;
begin
  Result := FChannel.Capacity;
end;

function TThreadPool.GetEnqueued: SizeInt;
begin
  Result := FChannel.PeekCount;
end;

function TThreadPool.GetThreadCount: SizeInt;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FPool.Count;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TThreadPool.SetThreadCount(aValue: SizeInt);
begin
  System.EnterCriticalSection(FLock);
  try
    if aValue > FPool.Count then
      PoolGrow(aValue)
    else
      if aValue < FPool.Count then
        PoolShrink(aValue);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TThreadPool.AddThread;
var
  I: SizeInt;
begin
  I := FPool.Add(TWorker.Create(Self, FChannel, FStackSize));
  FPool[I].Start;
end;

procedure TThreadPool.PoolGrow(aValue: SizeInt);
begin
  while FPool.Count < aValue do
    AddThread;
end;

procedure TThreadPool.PoolShrink(aValue: SizeInt);
begin
  if aValue < 1 then
    aValue := 1;
  TerminatePool;
  FChannel.Open;
  PoolGrow(aValue);
end;

procedure TThreadPool.TerminatePool;
var
  Thread: TWorker;
begin
  for Thread in FPool.Reverse do
    Thread.Terminate;
  FChannel.Close;
  while FPool.NonEmpty do
    begin
      Thread := FPool.Extract(Pred(FPool.Count));
      Thread.WaitFor;
      Thread.Free;
    end;
end;

procedure TThreadPool.Lock;
begin
  System.EnterCriticalSection(FLock);
end;

procedure TThreadPool.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TThreadPool.HandleException(aThreed: IWorkThread; e: Exception);
begin
  ReleaseExceptionObject;
  Assert(aThreed = aThreed);
  Assert(e = e);
end;

constructor TThreadPool.Create(aThreadCount: SizeInt; aQueueCapacity: SizeInt; aThreadStackSize: SizeUInt);
begin
  FStackSize := aThreadStackSize;
  FChannel := TChannel.Create(aQueueCapacity);
  if aThreadCount > 0 then
    PoolGrow(aThreadCount)
  else
    begin
      aThreadCount := TThread.ProcessorCount;
      PoolGrow(aThreadCount);
    end;
  System.InitCriticalSection(FLock);
end;

destructor TThreadPool.Destroy;
begin
  System.EnterCriticalSection(FLock);
  try
    TerminatePool;
    FPool.Clear;
    FChannel.Free;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TThreadPool.EnsureThreadCount(aValue: SizeInt);
begin
  System.EnterCriticalSection(FLock);
  try
    if aValue > FPool.Count then
      PoolGrow(aValue)
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TThreadPool.EnqueueTask(aTask: ITask);
begin
  FChannel.Send(aTask);
end;

function TThreadPool.TryEnqueueTask(aTask: ITask): Boolean;
begin
  Result := FChannel.TrySend(aTask);
end;

{ TPrioThreadPool.TWorker }

procedure TPrioThreadPool.TWorker.Execute;
var
  CurrTask: IPriorityTask = nil;
begin
  while not Terminated and FChannel.Receive(CurrTask) do
    try
      CurrTask.Execute;
    except
      FOwner.HandleException(Self, Exception(System.AcquireExceptionObject));
    end;
end;

constructor TPrioThreadPool.TWorker.Create(aOwner: TPrioThreadPool; aChannel: TChannel; aStackSize: SizeUInt);
begin
  inherited Create(True, aStackSize);
  FOwner := aOwner;
  FChannel := aChannel;
end;

{ TPrioThreadPool }

function TPrioThreadPool.GetCapacity: SizeInt;
begin
  Result := FChannel.Capacity;
end;

function TPrioThreadPool.GetEnqueued: SizeInt;
begin
  Result := FChannel.PeekCount;
end;

function TPrioThreadPool.GetThreadCount: SizeInt;
begin
  System.EnterCriticalSection(FLock);
  try
    Result := FPool.Count;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TPrioThreadPool.SetThreadCount(aValue: SizeInt);
begin
  System.EnterCriticalSection(FLock);
  try
    if aValue > FPool.Count then
      PoolGrow(aValue)
    else
      if aValue < FPool.Count then
        PoolShrink(aValue);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TPrioThreadPool.AddThread;
var
  I: SizeInt;
begin
  I := FPool.Add(TWorker.Create(Self, FChannel, FStackSize));
  FPool[I].Start;
end;

procedure TPrioThreadPool.PoolGrow(aValue: SizeInt);
begin
  while FPool.Count < aValue do
    AddThread;
end;

procedure TPrioThreadPool.PoolShrink(aValue: SizeInt);
begin
  if aValue < 1 then
    aValue := 1;
  TerminatePool;
  FChannel.Open;
  PoolGrow(aValue);
end;

procedure TPrioThreadPool.TerminatePool;
var
  Thread: TWorker;
begin
  for Thread in FPool.Reverse do
    Thread.Terminate;
  FChannel.Close;
  while FPool.NonEmpty do
    begin
      Thread := FPool.Extract(Pred(FPool.Count));
      Thread.WaitFor;
      Thread.Free;
    end;
end;

procedure TPrioThreadPool.Lock;
begin
  System.EnterCriticalSection(FLock);
end;

procedure TPrioThreadPool.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TPrioThreadPool.HandleException(aThreed: IWorkThread; e: Exception);
begin
  ReleaseExceptionObject;
  Assert(aThreed = aThreed);
  Assert(e = e);
end;

constructor TPrioThreadPool.Create(aThreadCount: SizeInt; aQueueCapacity: SizeInt; aThreadStackSize: SizeUInt);
begin
  FStackSize := aThreadStackSize;
  FChannel := TChannel.Create(aQueueCapacity);
  if aThreadCount > 0 then
    PoolGrow(aThreadCount)
  else
    begin
      aThreadCount := TThread.ProcessorCount;
      PoolGrow(aThreadCount);
    end;
  System.InitCriticalSection(FLock);
end;

destructor TPrioThreadPool.Destroy;
begin
  System.EnterCriticalSection(FLock);
  try
    TerminatePool;
    FPool.Clear;
    FChannel.Free;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TPrioThreadPool.EnsureThreadCount(aValue: SizeInt);
begin
  System.EnterCriticalSection(FLock);
  try
    if aValue > FPool.Count then
      PoolGrow(aValue)
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TPrioThreadPool.EnqueueTask(aTask: IPriorityTask);
begin
  FChannel.Send(aTask);
end;

function TPrioThreadPool.TryEnqueueTask(aTask: IPriorityTask): Boolean;
begin
  Result := FChannel.TrySend(aTask);
end;

end.

