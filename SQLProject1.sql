
------------------------------------------------------------------------------------------------------------
--mayýþý 1500 den az olup 50 saat ten fazla calýsan hardworkers larý bulup salarylerini %20 arttýrýyor
create procedure sp_updateSalaryOFHardWorkers
as
begin
update ew
set ew.salary=ew.salary+(ew.salary*20/100)
from EMPLOYEE e,EMPLOYEE_WORK ew,(	select e.empID eID
					from EMPLOYEE e join EMPLOYEE_WORK ew on e.duty=ew.duty
					where	ew.salary <= 1500 and
							(ew.workDays*ew.workHours) >=50) list
where	e.duty=ew.duty and
		e.empID=list.eID
		--e.empID=1 --kontrol için
end

--exec sp_updateSalaryOFHardWorkers

------------------------------------------------------------------------------------------------------------
--for given customerID extend the reservation date with given days

create procedure sp_extendReservatýon
@days smallint,@CID smallint
as
declare @date1 smalldatetime
declare @date2 smalldatetime
begin
	if(not exists(	select top 1 d.[Check-out] co
					from CUSTOMER c,RESERVATION r,DIRECTLY d
					where	c.custTC=@CID and
							c.custTC=r.custTC and
							r.resID=d.resID
					order by d.[Check-out] desc))
	begin
	raiserror('Customer must be directly reservated',14,1)
	return
	end
	else
	begin
	set @date1=GETDATE()
	set @date2=(	select top 1 d.[Check-out] co
					from CUSTOMER c,RESERVATION r,DIRECTLY d
					where	c.custTC=@CID and
							c.custTC=r.custTC and
							r.resID=d.resID
					order by d.[Check-out] desc)

		if(@date2<@date1)
		begin
		raiserror('Customer is not active',14,1)
		return
		end

		else
		begin
		update d
		set d.[Check-out]=d.[Check-out]+@days /*DATEADD(YEAR,-3,GETDATE())*/
		from CUSTOMER c join RESERVATION r on c.custTC=r.custTC
						join DIRECTLY d on r.resID=d.resID
		where	c.custTC=@CID
				
		end
	
	end
end

--exec sp_extendReservatýon 2,3
-----------------------------------------------------------------------------------------------------------------------------
--procedure for updating the firstly created bill table records from customer informations.

create proc sp_billUpdate
@cID smallint
as
declare @oTP smallint
declare @rTP smallint
begin
	if(not exists(select c.custTC from CUSTOMER c where c.custTC=@cID))
		begin
		raiserror('Customer not found',14,1)
		return end
	if(not exists(select r.TotalPaid from RESERVATION r where r.custTC=@cID))
		begin set @rTP=0 end
	else
		begin set @rTP=(select sum(r.TotalPaid) from RESERVATION r where r.custTC=@cID group by r.custTC) end
	if(not exists(select o.TotalPaid from  [ORDER] o where o.custTC=@cID))
		begin set @oTP=0 end
	else
		begin set @oTP=(select sum(o.TotalPaid) from  [ORDER] o where o.custTC=@cID group by o.custTC) end

update b
set b.PaidAmount = @oTP+@rTP
from  BILL b
where b.custTC=@cID
end

--exec sp_billUpdate 10

------------------------------------------------------------------------------------------------------------------------
--procedure to add customer and reservation

create proc sp_AddCustomer 

	@roomID smallint,
	@custTC smallint,
	@fname nvarchar(25),
	@lname nvarchar(25),
	@Gender bit,
	@Age smallint,
	@Adress nvarchar(50),
	@Email nvarchar(50),
	@PhoneNumber nvarchar(50),
	@manID smallint,
	@resType nchar(10)
	
	
as
begin
	if exists (select * from ROOM r, DIRECTLY d, RESERVATION rs where r.RoomID = rs.RoomID and rs.resID = d.resID and r.RoomID = @roomID and 
	GETDATE() between [Check-in] and [Check-out] )
	begin
	print('Room is not available at moment.')
	end
	else
	begin
	insert into CUSTOMER values (@custTC ,@fname ,@lname ,@Gender ,@Age ,@Adress ,@Email ,@PhoneNumber)
	insert into RESERVATION values(GETDATE(),@custTC,0,0,@roomID,@manID,@resType)

	end
end

--exec sp_AddCustomer 100, 24, aa, bb, 0, 12, zccz, jaja, 02555,4,OnlyBed
----------------------------------------------------------------------------------------------------------------------------------------
--delete the reservatýon directly onlýne record which has 3 years of past.
create procedure sp_deleteOldRecords AS
begin
declare @date smalldatetime
set @date=DATEADD(YEAR,-3,GETDATE())
select rs.resID
from RESERVATION rs
where rs.resID in (	select rs.resID
					from CUSTOMER c join RESERVATION rs on c.custTC=rs.custTC
					where rs.[Date] < DATEADD(YEAR,-3,GETDATE())
					group by rs.resID)
delete from RESERVATION
where resID in (	select rs.resID
					from CUSTOMER c join RESERVATION rs on c.custTC=rs.custTC
					where rs.[Date] < DATEADD(YEAR,-3,GETDATE())
					group by rs.resID)
delete from [ONLINE]
where resID in (	select rs.resID
					from CUSTOMER c join RESERVATION rs on c.custTC=rs.custTC
					where rs.[Date] < DATEADD(YEAR,-3,GETDATE())
					group by rs.resID)
delete from DIRECTLY
where resID in (	select rs.resID
					from CUSTOMER c join RESERVATION rs on c.custTC=rs.custTC
					where rs.[Date] < DATEADD(YEAR,-3,GETDATE())
					group by rs.resID)
if(	exists (
select c.custTC
from CUSTOMER c			
where c.custTC not in(	select c.custTC
						from CUSTOMER c join RESERVATION rs on c.custTC = rs.custTC
						group by c.custTC)
			))
begin
	delete from CUSTOMER
	where custTC not in (	select c.custTC
						from CUSTOMER c join RESERVATION rs on c.custTC = rs.custTC
						group by c.custTC)
end
end
--------------------------------------------------------------------------------------------------------

-- VIEW -1-
--en çok rezarvasyon yapan top manager ve ençok rezervasyon yaptýgý oda ve sayýsý

create view showTopManager AS
select  list1.mID as ManID,list.rID,list.cnt as Times
from			(	select top 1 r.roomID as rID,count(*) as cnt
					from ROOM r join RESERVATION rs on r.roomID=rs.roomID
								join MANAGER m on rs.manID=m.manID,
								(	select top 1 m.manID as mID,COUNT(*) as OdaSayýsý
									from MANAGER m join RESERVATION r on m.manID=r.manID
									group by m.manID
									order by COUNT(*) desc ) list1

					where m.manID=list1.mID
					group by r.roomID
					order by count(*) desc	) list,
				(	select top 1 m.manID as mID,COUNT(*) as OdaSayýsý
					from MANAGER m join RESERVATION r on m.manID=r.manID
					group by m.manID
					order by COUNT(*) desc ) list1
	

						

------------------------------------------------------------------------------------------------------------
--VIEW -2-
--show available rooms
create view showAvailableRooms AS
select *
from ROOM r
where r.RoomID not in (
						select r.RoomID
						from ROOM r join RESERVATION rs on r.RoomID=rs.RoomID
									join DIRECTLY d on rs.resID=d.resID
						where	d.[Check-in] <= GETDATE() and
								GETDATE() <= d.[Check-out]	)

-----------------------------------------------------------------------------------------------------------				
--VIEW -3-

--order totalspend ini product price larýný ve countlarý kullanarak hesaplayýp güncelliyor
--ayný þekilde reservasyon totalspend ini room price ve res_type price ýný kullanarak hesaplayýp güncelliyor

create view showTotalSpends AS
		select	r.resID rID,DATEDIFF(day,d.[Check-in],d.[Check-out])*(rt.Price+ro.Price) TotalSpend
		from RESERVATION_TYPE rt,ROOM ro,RESERVATION r join DIRECTLY d on r.resID=d.resID
		where	r.RoomID=ro.RoomID and
				r.resType=rt.resType
		union
		select	r.resID,DATEDIFF(day,d.ArrivalDate,d.DepartureDate)*(rt.Price+ro.Price)
		from RESERVATION_TYPE rt,ROOM ro,RESERVATION r join [ONLINE] d on r.resID=d.resID
		where	r.RoomID=ro.RoomID and
				r.resType=rt.resType
		union
		select o.orderID oID,sum(p.price*od.[count]) TotalSpend
		from ORDER_DETAILS od,PRODUCT p,[ORDER] o
		where	
			 o.orderID=od.orderID and
			od.productID=p.productID
		group by o.orderID




--------------------------------------------------------------------------------------
--VIEW -4-
--for last 6 months show the customer that has highest paidamount for each room that had reservation.

create view showGenerousCustomers AS
select distinct r.RoomID, c.custTC,list1.tp
from CUSTOMER c,CUSTOMER c1,RESERVATION rs,RESERVATION rs1,ROOM r,
					(	select  c.custTC as cID,sum(b.PaidAmount) as tp
						from CUSTOMER c join BILL b on c.custTC=b.custTC
						where c.custTC in	(select c.custTC
											from RESERVATION rs join CUSTOMER c on c.custTC=rs.custTC
											where rs.Date > DATEADD(MONTH,-6,GETDATE()))
						group by c.custTC) list1,

					(	select  c.custTC as cID,sum(b.PaidAmount) as tp
						from CUSTOMER c join BILL b on c.custTC=b.custTC
						where c.custTC in	(select c.custTC
											from RESERVATION rs join CUSTOMER c on c.custTC=rs.custTC
											where rs.Date > DATEADD(MONTH,-6,GETDATE()))
						group by c.custTC) list2
where	r.RoomID=rs.RoomID   and
		r.RoomID=rs1.RoomID  and
		rs.custTC=c.custTC	 and
		rs1.custTC=c1.custTC and
		c.custTC=list1.cID	 and
		c1.custTC=list2.cID  and
		list1.tp >= list2.tp


------------------------------------------------------------------------------------------------------------------------------
--TRIGGER-> when reservation totalPaid is updated it inserts a bill

CREATE TRIGGER createBILL ON RESERVATION
AFTER INSERT, UPDATE, DELETE AS 
BEGIN
	
	DECLARE @action as char(1);
	DECLARE @dtotalPaid as smallint
	DECLARE @itotalPaid as smallint
	DECLARE @cTC smallint

IF EXISTS(SELECT * FROM deleted)
	BEGIN
		IF EXISTS(SELECT * FROM inserted i)
			SET @action = 'U';--Update section
			SET @dtotalPaid=(select d.totalPaid from DELETED d)
			SET @itotalPaid=(select i.totalPaid from DELETED i)
			IF(@dtotalPaid=@itotalPaid)
				return
			IF(@dtotalPaid=NULL)
				SET @dtotalPaid=0;

			SET @cTC=(select i.custTC from inserted i)
			insert into BILL
			values(GETDATE(),@itotalPaid-@dtotalPaid,'NAKÝT',@cTC)

	END
ELSE
return
end
----------------------------------------------------------------------------------------------------
--TRIGGER -> when deleted room table
create trigger RemoveRoom
on Room
for Delete
as
print('You cannot delete rooms')
rollback transaction --yapýlan iþlemleri geri alýr.

----------------------------------------------------------------------------------------------------
--Check constraints
ALTER TABLE RESERVATION
ADD CHECK (totalSpend>=0)
ALTER TABLE RESERVATION
ADD CHECK (totalPaid>=0)
ALTER TABLE [ORDER]
ADD CHECK (totalSpend>=0)
ALTER TABLE [ORDER]
ADD CHECK (totalPaid>=0)

-------------------------------------------------------------------------------------------

