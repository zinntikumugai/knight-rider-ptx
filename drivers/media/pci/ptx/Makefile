pt3-objs	:= pt3_pci.o ptx_common.o
pxq3pe-objs	:= pxq3pe_pci.o ptx_common.o

obj-$(CONFIG_DVB_PT3)		+= pt3.o
obj-$(CONFIG_DVB_PXQ3PE)	+= pxq3pe.o

ccflags-y += -I$(srctree)/drivers/media/dvb-core -I$(srctree)/drivers/media/dvb-frontends -I$(srctree)/drivers/media/tuners
