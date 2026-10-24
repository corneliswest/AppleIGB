#ifndef __APPLE_IGB_H__
#define __APPLE_IGB_H__

#define MBit 1000000

enum {
	eePowerStateOff = 0,
	eePowerStateOn,
	eePowerStateCount
};

enum
{
    MEDIUM_INDEX_AUTO = 0,
    MEDIUM_INDEX_10HD,
    MEDIUM_INDEX_10FD,
    MEDIUM_INDEX_100HD,
    MEDIUM_INDEX_100FD,
    MEDIUM_INDEX_100FDFC,
    MEDIUM_INDEX_1000FD,
    MEDIUM_INDEX_1000FDFC,
    MEDIUM_INDEX_1000FDEEE,
    MEDIUM_INDEX_1000FDFCEEE,
    MEDIUM_INDEX_100FDEEE,
    MEDIUM_INDEX_100FDFCEEE,
    MEDIUM_INDEX_COUNT
};


enum {
    kSpeed1000MBit = 1000*MBit,
    kSpeed100MBit = 100*MBit,
    kSpeed10MBit = 10*MBit,
};

enum {
    kFlowControlTypeNone = 0,
    kFlowControlTypeRx = 1,
    kFlowControlTypeTx = 2,
    kFlowControlTypeRxTx = 3,
    kFlowControlTypeCount
};

enum {
    kEEETypeNo = 0,
    kEEETypeYes = 1,
    kEEETypeCount
};

/* Interrupt delivery mode chosen in initEventSources(). */
enum {
    kIntrModeLegacy = 0,    /* shared level-triggered INTx line */
    kIntrModeMSI = 1        /* PCI message-signalled interrupt */
};

/* Diagnostics: event codes recorded in the AppleIGB-Events ring (see dbgEvent()). */
enum {
    kDbgEvNone = 0, kDbgEvIrqMode, kDbgEvLinkUp, kDbgEvLinkDown, kDbgEvCarrierUp, kDbgEvCarrierDown,
    kDbgEvRestart, kDbgEvReinit, kDbgEvTxHang, kDbgEvTxStall, kDbgEvTxWake, kDbgEvRxCopyFail,
    kDbgEvRxAllocFail, kDbgEvPcieLost, kDbgEvDrsta, kDbgEvLinkCheck, kDbgEvEnable, kDbgEvDisable,
    kDbgEvWatchdogOff, kDbgEvIrqOnDisabled, kDbgEvIrqSpurious,
    kDbgEvCount
};

#define IGB_DBG_EVENTS 128

struct igb_dbg_counters {
    UInt32 irq_count, irq_spurious, irq_on_disabled, last_icr, poll_count, watchdog_ticks;
    UInt32 rx_v4, rx_v6, rx_arp, rx_oth, rx_drop, rx_cbfail, rx_alloc_fail, rx_csumerr, rx_ixsm, rx_ipcs, rx_l4cs;
    UInt32 tx_v4, tx_v6, tx_arp, tx_oth, tx_drop, tx_stall, tx_wake, tx_hang, tx_map_fail;
    UInt32 carrier_up, carrier_down, link_check, restart, reinit, pcie_lost;
};

struct igb_dbg_event {
    UInt64 t_us;        /* wall clock, microseconds since the epoch */
    UInt32 arg;
    UInt16 code;
    UInt16 repeat;      /* consecutive identical events folded into one entry */
};

#define super IOEthernetController

class AppleIGB: public super
{
	
	OSDeclareDefaultStructors(AppleIGB);
	
public:
	// --------------------------------------------------
	// IOService (or its superclass) methods.
	// --------------------------------------------------
	
	virtual bool start(IOService * provider);
	virtual void stop(IOService * provider);
	virtual bool init(OSDictionary *properties);
	virtual void free();

	// --------------------------------------------------
	// Power Management Support
	// --------------------------------------------------
	virtual IOReturn registerWithPolicyMaker(IOService* policyMaker);
    virtual IOReturn setPowerState( unsigned long powerStateOrdinal, IOService *policyMaker );
    virtual void systemWillShutdown(IOOptionBits specifier);
	
	// --------------------------------------------------
	// IONetworkController methods.
	// --------------------------------------------------
	
	virtual IOReturn enable(IONetworkInterface * netif);
	virtual IOReturn disable(IONetworkInterface * netif);
	
	virtual UInt32 outputPacket(mbuf_t m, void * param);
	
	virtual void getPacketBufferConstraints(IOPacketBufferConstraints * constraints) const;
	
	virtual IOOutputQueue * createOutputQueue();
	
	virtual const OSString * newVendorString() const;
	virtual const OSString * newModelString() const;
	
	virtual IOReturn selectMedium(const IONetworkMedium * medium);
	virtual bool configureInterface(IONetworkInterface * interface);
	
	virtual bool createWorkLoop();
	virtual IOWorkLoop * getWorkLoop() const;
	
	//-----------------------------------------------------------------------
	// Methods inherited from IOEthernetController.
	//-----------------------------------------------------------------------
	
	virtual IOReturn getHardwareAddress(IOEthernetAddress * addr);
	virtual IOReturn setHardwareAddress(const IOEthernetAddress * addr);
	virtual IOReturn setPromiscuousMode(bool active);
	virtual IOReturn setMulticastMode(bool active);
	virtual IOReturn setMulticastList(IOEthernetAddress * addrs, UInt32 count);
	virtual IOReturn getChecksumSupport(UInt32 *checksumMask, UInt32 checksumFamily, bool isOutput);
	virtual IOReturn setMaxPacketSize (UInt32 maxSize);
	virtual IOReturn getMaxPacketSize (UInt32 *maxSize) const;
	virtual IOReturn getMinPacketSize (UInt32 *minSize) const;
    virtual IOReturn setWakeOnMagicPacket(bool active);
    virtual IOReturn getPacketFilters(const OSSymbol * group, UInt32 * filters) const;
    virtual UInt32 getFeatures() const;
    IOSimpleLock* getTxLock() const { return txLock; }

    // Diagnostics, published in the IORegistry as "AppleIGB-DBG" and "AppleIGB-Events"
    // (ioreg -r -c AppleIGB -l). Counters are best-effort and not locked.
    struct igb_dbg_counters dbg;
    void dbgEvent(UInt16 code, UInt32 arg);
    void dbgCountEtherType(mbuf_t skb, bool tx);
    void dbgPublish(bool force);

private:
	IOWorkLoop* workLoop;
	IOSimpleLock* txLock;   // protects TX ring between outputPacket and igb_clean_tx_irq
	IOPCIDevice* pdev;
	OSDictionary * mediumDict;
	IONetworkMedium * mediumTable[MEDIUM_INDEX_COUNT];
	IOOutputQueue * transmitQueue;
	
	IOInterruptEventSource * interruptSource;
	int interruptMode;      /* kIntrModeLegacy / kIntrModeMSI */
	int interruptIndex;     /* provider interrupt index in use */
	struct igb_dbg_event dbgEvents[IGB_DBG_EVENTS];
	UInt32 dbgEvHead;
	UInt64 dbgLastPublish;
	IOTimerEventSource * watchdogSource;
	IOTimerEventSource * resetSource;
	IOTimerEventSource * dmaErrSource;

	IOEthernetInterface * netif;
	IONetworkStats * netStats;
	IOEthernetStats * etherStats;

	IOMemoryMap * csrPCIAddress;
	
	IOMbufNaturalMemoryCursor * txMbufCursor;

	bool enabledForNetif;
	bool bSuspended;
	bool useTSO;

    bool linkUp;
    bool stalled;

    UInt16 eeeMode;

	UInt32 iff_flags;
	UInt32 _features;
	UInt32 preLinkStatus;
	UInt32 powerState;
	UInt32 _mtu;
    SInt32 txNumFreeDesc;

    UInt32 chip_idx;

	struct igb_adapter priv_adapter;
public:
	void startTxQueue();
	void stopTxQueue();
	UInt32 mtu() { return _mtu; }
	UInt32 flags(){ return iff_flags;}
	UInt32 features() { return _features; }
	igb_adapter* adapter(){ return &priv_adapter; }
	IONetworkStats* getNetStats(){ return netStats; }
	IOEthernetStats* getEtherStats() { return etherStats; }
	dma_addr_t mapSingle( mbuf_t );
	void receive(mbuf_t skb );
	void flushInput();
	void setVid(mbuf_t skb, UInt16 vid);
	IOMbufNaturalMemoryCursor * txCursor(){ return txMbufCursor; }
	void rxChecksumOK( mbuf_t, UInt32 flag );
	bool running(){return enabledForNetif;}
	bool queueStopped(){return txMbufCursor == NULL || stalled;}
	bool carrier();
	void setCarrier(bool);
    
    void setTimers(bool enable);
private:
	void interruptOccurred(IOInterruptEventSource * src, int count);
	
	void watchdogTask();
	void updatePhyInfoTask();

    void intelRestart();
    bool intelCheckLink(struct igb_adapter *adapter);
    void setLinkUp();
    void setLinkDown();
    void checkLinkStatus();


    UInt16 intelSupportsEEE(struct igb_adapter *adapter);
    bool setupMediumDict();

    void intelSetupAdvForMedium(const IONetworkMedium *medium);
	bool addNetworkMedium(UInt32 type, UInt32 bps, UInt32 index);

	bool initEventSources( IOService* provider );

	bool igb_probe();
	void igb_remove();

	bool getBoolOption(const char *name, bool defVal);
	int getIntOption(const char *name, int defVal, int maxVal, int minVal );

public:
	static void interruptHandler(OSObject * target,
								 IOInterruptEventSource * src,
								 int count );
	
	

	static void watchdogHandler(OSObject * target, IOTimerEventSource * src);
	static void resetHandler(OSObject * target, IOTimerEventSource * src);

};


#endif //__APPLE_IGB_H__
