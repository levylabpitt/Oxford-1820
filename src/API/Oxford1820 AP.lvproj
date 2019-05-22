<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="16008000">
	<Item Name="My Computer" Type="My Computer">
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="FGV" Type="Folder">
			<Item Name="FGV_PSP - Mercury Action Status.vi" Type="VI" URL="../FGV/FGV_PSP - Mercury Action Status.vi"/>
			<Item Name="FGV_PSP - Mercury Actions.vi" Type="VI" URL="../FGV/FGV_PSP - Mercury Actions.vi"/>
			<Item Name="FGV_PSP - Mercury Remote.vi" Type="VI" URL="../FGV/FGV_PSP - Mercury Remote.vi"/>
			<Item Name="FGV_PSP - Mercury Status.vi" Type="VI" URL="../FGV/FGV_PSP - Mercury Status.vi"/>
			<Item Name="FGV_PSP - Mercury Targets.vi" Type="VI" URL="../FGV/FGV_PSP - Mercury Targets.vi"/>
		</Item>
		<Item Name="private" Type="Folder">
			<Item Name="API Test.vi" Type="VI" URL="../private/API Test.vi"/>
			<Item Name="check HOLD and resend.vi" Type="VI" URL="../private/check HOLD and resend.vi"/>
			<Item Name="check RTOS and resend.vi" Type="VI" URL="../private/check RTOS and resend.vi"/>
			<Item Name="Mercury_GoToField_SubVI.vi" Type="VI" URL="../private/Mercury_GoToField_SubVI.vi"/>
			<Item Name="wait HOLD.vi" Type="VI" URL="../private/wait HOLD.vi"/>
			<Item Name="wait Targets match.vi" Type="VI" URL="../private/wait Targets match.vi"/>
		</Item>
		<Item Name="public" Type="Folder">
			<Item Name="1820FloatApprox.vi" Type="VI" URL="../public/1820FloatApprox.vi"/>
		</Item>
		<Item Name="Typedefs" Type="Folder">
			<Item Name="Actions.ctl" Type="VI" URL="../Typedefs/Actions.ctl"/>
			<Item Name="Status.ctl" Type="VI" URL="../Typedefs/Status.ctl"/>
			<Item Name="Targets.ctl" Type="VI" URL="../Typedefs/Targets.ctl"/>
		</Item>
		<Item Name="Mercury_GoToField.vi" Type="VI" URL="../Mercury_GoToField.vi"/>
		<Item Name="Dependencies" Type="Dependencies">
			<Item Name="user.lib" Type="Folder">
				<Item Name="Wait (ms)__ogtk.vi" Type="VI" URL="/&lt;userlib&gt;/_OpenG.lib/time/time.llb/Wait (ms)__ogtk.vi"/>
			</Item>
		</Item>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
