c shift the LP=protonation position to an "empty" region
      subroutine shiftlp(n,at,ia1,xyz,ex,ey,ez)
      implicit none
      integer n,at(n),ia1
      real*8 xyz(3,n),ex,ey,ez

      real*8 r0,r1,r2,exmin,eymin,ezmin,rmin,xsave,ysave,zsave,rmax
      real x,f
      integer icount,j

      r0=2.5d0
      rmin=1.d+42
      rmax=0
      icount=0

  10  f=1.0
      call random_number(x)
      if(x.lt.0.5)f=-1.0
      call random_number(x)
      ex=xyz(1,ia1)+x*f*r0
      call random_number(x)
      ey=xyz(2,ia1)+x*f*r0
      call random_number(x)
      ez=xyz(3,ia1)+x*f*r0
      r1=sqrt((xyz(1,ia1)-ex)**2+(xyz(2,ia1)-ey)**2+(xyz(3,ia1)-ez)**2)
      if(abs(r0-r1).gt.0.1) goto 10
      rmin=1.d+42
      do j=1,n
         r2=sqrt((xyz(1,j)-ex)**2+(xyz(2,j)-ey)**2+(xyz(3,j)-ez)**2)
         if(r2.lt.rmin.and.j.ne.ia1) then
            rmin=r2
            exmin=ex
            eymin=ey
            ezmin=ez
         endif
      enddo
      if(rmin.gt.rmax)then
         rmax=rmin
         xsave=exmin
         ysave=eymin
         zsave=ezmin
      endif
      icount=icount+1
      if(icount.lt.100) goto 10

      ex=xsave
      ey=ysave
      ez=zsave

      end
