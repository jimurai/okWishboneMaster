import ok
import numpy as np

class okWishboneMaster:
    def __init__(self, config_file_name=''):
        self.ConfigFile = config_file_name
        self.dtype = np.dtype('<i2')
        return
    
    def InitializeDevice(self):
        # Open the first device we find.
        self.dev = ok.okCFrontPanel()
        self.pll = ok.okCPLL22150()
        if (self.dev.NoError != self.dev.OpenBySerial("")):
            print("A device could not be opened. Is one connected?")
            return(False)

        # Get some general information about the device.
        self.devInfo = ok.okTDeviceInfo()
        if (self.dev.NoError != self.dev.GetDeviceInfo(self.devInfo)):
            print("Unable to retrieve device information.")
            return(False)
        print("         Product: {}".format(self.devInfo.productName))
        print("Firmware version: {}.{}".format(self.devInfo.deviceMajorVersion, self.devInfo.deviceMinorVersion))
        print("   Serial Number: {}".format(self.devInfo.serialNumber))
        print("       Device ID: {}".format(self.devInfo.deviceID.split('\0')[0]))

        self.dev.LoadDefaultPLLConfiguration()

        # Download the configuration file.
        if self.ConfigFile == '':
            if self.devInfo.productName == 'XEM6002-LX9':
                self.ConfigFile = r'..\okwmb-xem6002.bit'
        if (self.dev.NoError != self.dev.ConfigureFPGA(self.ConfigFile)):
            return(False)

        # Check for FrontPanel support in the FPGA configuration.
        if (False == self.dev.IsFrontPanelEnabled()):
            return(False)
        
        # Initialisation completed successfully
        return(True)

    def Reset(self):
        # Perform the reset
        self.dev.ActivateTriggerIn(0x40, 0)
        # Wait for a bit
        time.sleep(0.1)        
        # Set the default register values - just incase the FPGA hasn't
        self.dev.SetWireInValue(0x00, 0)
        self.dev.SetWireInValue(0x01, 0)
        self.dev.UpdateWireIns()        

    def SingleRead(self,addr):
        # Set address
        self.dev.SetWireInValue(0x00, addr&0xFFFF)
        self.dev.UpdateWireIns()
        # Trigger the read
        self.dev.ActivateTriggerIn(0x40, 1)
        # Wait for read to finish
        while not self.isFinished():
            # TODO: Pause to give other threads some time
            pass
        # Get data
        self.dev.UpdateWireOuts()
        data = self.dev.GetWireOutValue(0x20)
        return data

    def SingleWrite(self, addr, data):
        # Set address and data
        self.dev.SetWireInValue(0x00, addr&0xFFFF)
        self.dev.SetWireInValue(0x01, data&0xFFFF)
        self.dev.UpdateWireIns()
        # Trigger the write
        self.dev.ActivateTriggerIn(0x40, 2)
        # Wait for write to finish
        while not self.isFinished():
            # TODO: Pause to give other threads some time
            pass
        return

    def BurstRead(self, addr, N):
        # Set address
        self.dev.SetWireInValue(0x00, addr&0xFFFF)
        self.dev.UpdateWireIns()
        # Fetch the waveform from RAM
        read_buffer = bytearray(N*2)        
        self.dev.ReadFromBlockPipeOut(0xa0, len(read_buffer), read_buffer)
        # Wait for burst to finish
        while not self.isFinished():
            # TODO: Pause to give other threads some time
            pass
        # Re-format the bytearray
        return np.frombuffer(read_buffer, dtype=self.dtype)

    def BurstWrite(self, addr, data):
        # Set address
        self.dev.SetWireInValue(0x00, addr&0xFFFF)
        self.dev.UpdateWireIns()
        # Serialise the data array into a bytearray
        writearray = bytearray(data.astype(self.dtype).tostring('C'))
        # Trigger the burst write
        self.dev.WriteToBlockPipeIn(0x80, len(writearray), writearray)        
        # Wait for burst to finish
        while not self.isFinished():
            # TODO: Pause to give other threads some time
            pass
        return

    def isFinished(self):
        return self.pollTriggerOuts(1)

    def isInterrupt(self):
        return self.pollTriggerOuts(2)
        
    def pollTriggerOuts(self,id):
        self.dev.UpdateTriggerOuts()
        return self.dev.IsTriggered(0x60, id)

    def ReadDebug(self):
        self.dev.UpdateWireOuts()
        data = self.dev.GetWireOutValue(0x21)
        return data
        
# Main code - currently benchtest only
if __name__ == '__main__':
    import sys
    import time

    okwbm = okWishboneMaster(r'..\ise\ok_wbm.bit')
    if (False == okwbm.InitializeDevice()):
        print("FPGA configuration failed.")
        sys.exit()
        
    # Reset the digital system
    okwbm.Reset()
    
    # okwbm.SingleWrite(0,1)
    
    N = 16
    for i in range(N):
        print(i,okwbm.SingleRead(i))
        okwbm.SingleWrite(i,i**2)
    for i in [0,2,15,3,4,6,5,7,9,8,10,11,13,12,14,1]:
        print(i,okwbm.SingleRead(i))
        
    # Load address and write something to it
    N = 16
    wave = np.arange(N,dtype=np.int16)
    print wave
    okwbm.BurstWrite(16,wave[:4])
    okwbm.BurstWrite(16,wave[4:8])
    okwbm.BurstWrite(16,wave[8:12])
    okwbm.BurstWrite(16,wave[12:])
    
    print okwbm.BurstRead(16,4),
    print okwbm.BurstRead(16,4),
    print okwbm.BurstRead(16,4),
    print okwbm.BurstRead(16,4)
    