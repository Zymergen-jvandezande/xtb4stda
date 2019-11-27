

      subroutine local(nat,at,nbf,nao,ihomo,xyz,z,
     .                 focc,s,p,cmo,eig,q,etot,gbsa)
      implicit none
      integer nao,ihomo,nat,at(nat),nbf
      real*8 cmo(nao,nao),eig(nao),focc(nao)
      real*8 s(nao,nao),xyz(3,nat),z(nat),q(nat)
      real*8 p(nao,nao),etot
      logical gbsa
      include 'ehtcommon.fh'
      include 'setcommon.fh'

      real*8, allocatable ::op(:,:)
      real*8, allocatable ::oc(:,:,:)
      real*8, allocatable ::cca(:)
      real*8, allocatable ::dip2(:)
      real*8, allocatable ::qua (:,:)
      real*8, allocatable ::dip (:,:)
      real*8, allocatable ::ecent(:,:),qcent(:,:),ecent2(:,:)
      real*8, allocatable ::d(:,:)
      real*8, allocatable ::f(:)
      real*8, allocatable ::eiga(:)
      real*8, allocatable ::xcen(:)
      real*8 ,allocatable ::qmo(:,:)
      real*8 ,allocatable ::tmpq(:,:)
      real*8 ,allocatable ::rr(:)
      real*8, allocatable ::wbo(:,:)
      real*8, allocatable ::xyztmp(:,:)
      real*4 ,allocatable ::rklmo(:,:)
      integer,allocatable ::ind(:)
      integer,allocatable ::lneigh(:,:)
      integer,allocatable ::aneigh(:,:)

      integer mo,n,i,j,k,ii,jj,imem(nat),idum,isc,iso,nop,pilist(ihomo)
      integer lamdu1,lamdu2,imo1,imo2,iso1,iso2,ij,jdum,maxlp,maxpi,is1
      integer ilumo,klev,nlev,nn,m,ldum(ihomo),sigrel(3,ihomo),npi,is2
      integer i1,i2,i3,is3,ipi,piset(nat),ncyc,j1,j2,smo,pmo,nl,nm,nr
      integer imo,new
      real*8 dd,dum,det,pp,dtot(3),diptot,thr,t0,w0,t1,w1,vec1(3),v(6)
      real*8 elumo,ehomo,qhl(nat,2),ps,efh,efl,r1,r2,pithr,vec2(3),pi
      real*8 praxis(3,3),aa,bb,cc
      data pi/3.1415926535897932384626433832795029d0/
      character*80 atmp
      character*2 asym
      character*5 lmostring(4)
      data lmostring/'sigma','LP   ','pi   ','delpi'/
      logical l1,l2,l3,bndcheck,flip
      integer LWORK,IWORK,LIWORK,INFO

                                                      call timing(t0,w0)
      write(*,*)
      write(*,*)'localization/xTB-IFF output generation'
      n=ihomo
      ilumo=n+1

      if(ilumo.gt.nao)then
         elumo=1000.
      else
         elumo=eig(ilumo)
      endif
      efh=eig(n)
      efl=elumo

c     HOMO/LUMO populations for xTB FF (CT terms)
      qhl = 0
      thr = 0.01

      if(ihomo.eq.0) then
        ! the HOMO is non-existing, place at unrealistically low energy
        ehomo=-999.999999990d0
        qhl(1:nat,1)=0.0d0
      else
        klev=0
        ehomo=0
        do nlev=ihomo,1,-1 ! loop over highest levels
        if(efh-eig(nlev).gt.thr) exit
        klev=klev+1
        ehomo=ehomo+eig(nlev)
        do i=1,nao
           ii=aoat2(i)
           do j=1,i-1
              jj=aoat2(j)
              ps=s(j,i)*cmo(j,nlev)*cmo(i,nlev)
              qhl(ii,1)=qhl(ii,1)+ps
              qhl(jj,1)=qhl(jj,1)+ps
           enddo
           ps=s(i,i)*cmo(i,nlev)*cmo(i,nlev)
           qhl(ii,1)=qhl(ii,1)+ps
        enddo
        enddo
        dum=1./float(klev)
        ehomo=ehomo*dum
        qhl(1:nat,1)=qhl(1:nat,1)*dum
        write(*,*)'averaging CT terms over ',klev,' occ. levels'
      endif

      klev=0
      elumo=0
      do nlev=ilumo,nao ! loop over highest levels
      if(eig(nlev)-efl.gt.thr) exit
      klev=klev+1
      elumo=elumo+eig(nlev)
      do i=1,nao
         ii=aoat2(i)
         do j=1,i-1
            jj=aoat2(j)
            ps=s(j,i)*cmo(j,nlev)*cmo(i,nlev)
            qhl(ii,2)=qhl(ii,2)+ps
            qhl(jj,2)=qhl(jj,2)+ps
         enddo
         ps=s(i,i)*cmo(i,nlev)*cmo(i,nlev)
         qhl(ii,2)=qhl(ii,2)+ps
      enddo
      enddo
      dum=1./float(klev)
      elumo=elumo*dum
      qhl(1:nat,2)=qhl(1:nat,2)*dum
      write(*,*)'averaging CT terms over ',klev,' virt. levels'
      if(ilumo.gt.nao)then
         elumo=1000.
         qhl(1:nat,2)=0
      endif

      allocate(cca(nao*nao),xcen(n),lneigh(4,n),aneigh(2,n))
      allocate(d(n,n),ecent(n,4),eiga(n),qcent(n,3),ecent2(n,4))

c do only occ. ones
      cca=0
      k=  0
      do i=1,n
         k=k+1
         eiga(k)=eig(i)
         do j=1,nao
            cca(j+(k-1)*nao)=cmo(j,i)
         enddo
      enddo

      nop=3
c     dipole integrals
      allocate(dip2(nao*nao),dip(nbf*(nbf+1)/2,3),op(n*(n+1)/2,nop))
c    .         qua (nbf*(nbf+1)/2,3))
      call Dints  (nat,nbf,xyz,dip(1,1),dip(1,2),dip(1,3))
c     call DQ3ints(nat,nbf,xyz,dip(1,1),dip(1,2),dip(1,3),
c    .                         qua(1,1),qua(1,2),qua(1,3))
      call cao2saop(nbf,nao,dip(1,1))
      call cao2saop(nbf,nao,dip(1,2))
      call cao2saop(nbf,nao,dip(1,3))
c     call cao2saop(nbf,nao,qua(1,1))
c     call cao2saop(nbf,nao,qua(1,2))
c     call cao2saop(nbf,nao,qua(1,3))
c     d=0
      do mo=1,3
      call onetri(1,dip(1,mo),dip2,cca,nao,n)
      k=0
      do i=1,n
         do j=1,i
            k=k+1
            op(k,mo)=dip2(j+(i-1)*n)
         enddo
      enddo
      enddo

c     compute dipole moment core part
      dtot = 0
      do i=1,nat
         dtot(1)=dtot(1)+xyz(1,i)*z(i)
         dtot(2)=dtot(2)+xyz(2,i)*z(i)
         dtot(3)=dtot(3)+xyz(3,i)*z(i)
      enddo
      k=0
      do i=1,n
         k=k+i
         dtot(1)=dtot(1)+op(k,1)*focc(i)
         dtot(2)=dtot(2)+op(k,2)*focc(i)
         dtot(3)=dtot(3)+op(k,3)*focc(i)
      enddo
      diptot=sqrt(dtot(1)**2+dtot(2)**2+dtot(3)**2)
      write(*,*)'dipole moment from electron density (au)'
      write(*,*)'    X       Y       Z   '
      write(*,'(3f9.4,''  total (Debye): '',f8.3)')
     .      dtot(1),dtot(2),dtot(3),diptot*2.5418

                                                      call timing(t1,w1)
                                 call prtime(6,t1-t0,w1-w0,'init local')
c do optimization
      write(*,*) 'doing rotations ...'
      call lopt(.true.,n,3,1.d-6,op,d)

      write(*,*) 'doing transformations ...'
c MO charge center
      k=0
      do i=1,n
         k=k+i
         ecent(i,1)=-op(k,1)
         ecent(i,2)=-op(k,2)
         ecent(i,3)=-op(k,3)
      enddo

c LMO fock matrix
      allocate(f(n))
      do i=1,n
         dum=0.0d0
         do k=1,n
            dum=dum+eiga(k)*d(k,i)*d(k,i)
         enddo
         f(i)=dum
      enddo
      call lmosort2(n,f,d,ecent)

c the lmos
      CALL DGEMM('N','N',nao,n,n,1.D0,cca,nao,d,n,0.D0,cmo,nao)

c X^2,Y^2,Z^2 over LMOs
c     k=0
c     do i=1,n
c        k=k+1
c        do j=1,nao
c           cca(j+(k-1)*nao)=cmo(j,i)
c        enddo
c     enddo
c     do mo=1,3
c        call onetri(1,qua(1,mo),dip2,cca,nao,n)
c        do i=1,n
c           qcent(i,mo)=dip2(i+(i-1)*n)
c        enddo
c     enddo
c     deallocate(qua)

c     do i=1,n
c        r1=sum(ecent(i,1:3)**2)
c        r2=sum(-qcent(i,1:3))
c        ecent(i,4)=sqrt(r2-r1)
c     enddo

      pithr=2.20  ! below is pi, large is pi deloc (typ=4)

c number of centers for each mo
      allocate(qmo(nat,n))
      call mocent(nat,nao,n,cmo,s,qmo,xcen)

      allocate(rklmo(5,2*n))
      write(*,*) 'lmo centers(Z=2) and atoms on file <lmocent.coord>'
      write(*,*) 'LMO Fii/eV  ncent    charge center   contributions...'
      open(unit=33,file='xtbscreen.xyz')

      allocate(tmpq(nat,n))
      tmpq(1:nat,1:n)=qmo(1:nat,1:n)
      maxlp=0
      maxpi=0
      do i=1,n
         do j=1,nat
            imem(j)=j
         enddo
         call lmosort(nat,n,i,imem,qmo)
         idum=1
         do j=1,nat
            if(qmo(j,i).gt.0.07) idum=j
         enddo
         if(nat.eq.1)then
         jdum=2
         else
         call lmotype(nat,at,xyz,ecent(i,1),ecent(i,2),ecent(i,3),
     .                imem(1),imem(2),xcen(i),.false.,pithr,jdum)
         endif
         rklmo(1:3,i)=ecent(i,1:3)
         rklmo(  4,i)=ecent(i,  4)
         rklmo(  5,i)=real(jdum)
         if(jdum.eq.2)maxlp=i
         if(jdum.eq.3)maxpi=i
      enddo
      qmo(1:nat,1:n)=tmpq(1:nat,1:n)
      deallocate(tmpq)


      do i=1,n
         do j=1,nat
            imem(j)=j
         enddo
         call lmosort(nat,n,i,imem,qmo)
         idum=1
         do j=1,nat
            if(qmo(j,i).gt.0.07) idum=j
         enddo
         if(nat.eq.1)then
         jdum=1
         else
         call lmotype(nat,at,xyz,ecent(i,1),ecent(i,2),ecent(i,3),
     .                imem(1),imem(2),xcen(i),.true.,pithr,jdum)
         endif
         write(*,'(i5,1x,a5,2f7.2,3f10.5,12(i5,a2,'':'',f6.2))')
     .   i,lmostring(jdum),27.2113957*f(i),xcen(i),ecent(i,1:3),
     .   (imem(j),asym(at(imem(j))),qmo(j,i),j=1,idum)

c        write + LP/pi as H for protonation search
         if(jdum.gt.1) then
            if( i.eq.maxlp. or. (i.eq.maxpi.and.maxlp.eq.0) )then
              write(atmp,'(''coordprot.0'')')
              open(unit=21,file=atmp)
              write(21,'(''$coord'')')
              do ii=1,nat
               write(21,'(3F24.10,5x,a2)') xyz(1:3,ii),asym(at(ii))
              enddo
              write(21,'(3F24.10,5x,a2)') ecent(i,1:3),asym(1)
              write(21,'(''$end'')')
              write(21,'(''$set'')')
              write(21,'('' chrg '',i2)')ichrg+1
              write(21,'('' ewin_conf 50.0 '')')
              write(21,'(''$end'')')
              close(21)
            else
              write(33,*) nat+1
              write(33,*)
              do ii=1,nat
               write(33,'(a2,3F24.10)')asym(at(ii)),xyz(1:3,ii)*0.529167
              enddo
              write(33,'(a2,3F24.10)') asym(1),ecent(i,1:3)*0.529167
            endif
         endif

      enddo
c     close(33)

cccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      new=0
      if(maxval(rklmo(5,1:n)).ge.3.)then
      write(*,*) 'starting deloc pi regularization ...'

      call atomneigh(n,nat,xyz,ecent,aneigh) ! the nearest  atom neighbors for each LMO
      call lmoneigh (n,rklmo,ecent,aneigh,lneigh)   ! the nearest LMO neighbor but not LP

      ldum = -1
      do i=1,n
         if(int(rklmo(5,i)).ge.3.and.ldum(i).ne.1)then
            flip=.false.
            call piorient(ecent(i,:),ecent(lneigh(1,i),:),flip) ! check for same alignment of pi orbitals
            if(flip) then
              ldum(i)=1        ! i itself is the pi DOWN counterpart and lneigh(1,i) contains the pi UP part
              ldum(lneigh(1,i))=0
            else
              ldum(i)=0
              ldum(lneigh(1,i))=1       ! lneigh(1,i) contains the pi DOWN counterpart
            endif
         endif
      enddo
      k=0
      piset=0
      do i=1,n
         if(ldum(i).eq.0)then
            k=k+1
            pilist(k)=i               ! UP plane unique pi list
            piset(aneigh(1,i))=1
            piset(aneigh(2,i))=1
         endif
      enddo
      npi=k


c     determine for each deloc pi bond sigma bonds which are in the pi system
      j=0
      ldum=0
      nn=0
      sigrel=0
      do i=1,npi
         ipi=pilist(i)
         call irand3(i1,i2,i3)    ! change order of lookup
         is1=lneigh(i1+1,ipi)
         is2=lneigh(i2+1,ipi)
         is3=lneigh(i3+1,ipi)
         l1 =bndcheck(nat,piset,aneigh(1,is1),aneigh(2,is1)) !do bonds on ipi belong to the pi system?
         l2 =bndcheck(nat,piset,aneigh(1,is2),aneigh(2,is2))
         l3 =bndcheck(nat,piset,aneigh(1,is3),aneigh(2,is3))
         if(l1.and.ldum(is1).eq.0)then
            ldum(is1)=1
            sigrel(1,i)=is1
         endif
         if(l2.and.ldum(is2).eq.0)then
            ldum(is2)=1
            sigrel(2,i)=is2
         endif
         if(l3.and.ldum(is3).eq.0)then
            ldum(is3)=1
            sigrel(3,i)=is3
         endif
      enddo

      ldum=0
      do i=1,npi
         ipi=pilist(i)
         do j=1,3
         is1=sigrel(j,i)
         if(is1.gt.0)ldum(is1)=ldum(is1)+1
         enddo
      enddo

      write(*,*) 'thr ',pithr, '# pi deloc LMO',npi


      allocate(wbo(nat,nat))
      wbo=0.0d0
      call wiberg_nosort(nat,nao,at,xyz,p,s,wbo,.false.)

c     now create new LMO
      k=0
      m=0
      do i=1,npi
         pmo=pilist(i)
         i1 = aneigh(1,pmo)
         i2 = aneigh(2,pmo)
         dd=wbo(i2,i1)
         do j=1,3
         smo=sigrel(j,i)
         if(rklmo(5,smo).ne.1) cycle
!         if(rklmo(5,smo).eq.0.or.rklmo(5,smo).eq.2) cycle
         j1 = aneigh(1,smo)
         j2 = aneigh(2,smo)
         dum=wbo(j2,j1)
         ! take difference of pi-bond order (i.e., WBO > 1) relative to its sum (i.e., number of pi-electrons distributed among the 3 centers)
         pp=abs((dum-dd)/(dum+dd-2.0d0))
         if(pp.ge.0.50d0) cycle
c                              pi atom  center  sigma (nl,nm,nr)
         ! from 3 atoms A-B=C, find central atom (B)
         call threeoutfour(i1,i2,j1,j2,nl,nm,nr)
         if(nl.eq.0) cycle                ! fall back =do nothing if assignment fails
         vec1(1:3)=xyz(1:3,nm)
         vec2(1:3)=(xyz(1:3,nl)+xyz(1:3,nr))*0.5
         dtot(1:3)=rklmo(1:3,pmo)
         call calcrotation(dtot,vec2,vec1-vec2,pi)   ! project upper pi center to other bond
         k=k+1
         rklmo(1:3,n+k)= dtot(1:3)
         rklmo(4:5,n+k)=rklmo(4:5,pmo)
c        add to screen file, protomer search
         write(33,*) nat+1
         write(33,*)
         do ii=1,nat
            write(33,'(a2,3F24.10)')asym(at(ii)),xyz(1:3,ii)*0.529167
         enddo
         write(33,'(a2,3F24.10)') asym(1),dtot(1:3)*0.529167
         imo=lneigh(1,pmo)
         vec1(1:3)=xyz(1:3,nm)
         vec2(1:3)=(xyz(1:3,nl)+xyz(1:3,nr))*0.5
         dtot(1:3)=rklmo(1:3,imo)
         call calcrotation(dtot,vec2,vec1-vec2,pi)   ! project bottom pi center to other bond
         k=k+1
         rklmo(1:3,n+k)= dtot(1:3)
         rklmo(4:5,n+k)=rklmo(4:5,imo)
         rklmo(  5,smo)=0 ! remove sigma
c        add to screen file, protomer search
         write(33,*) nat+1
         write(33,*)
         do ii=1,nat
            write(33,'(a2,3F24.10)')asym(at(ii)),xyz(1:3,ii)*0.529167
         enddo
         write(33,'(a2,3F24.10)') asym(1),dtot(1:3)*0.529167
         m=m+1
         enddo
      enddo
      new=k

      close(33)

      deallocate(wbo)


      endif
cccccccccccccccccccccccccccccccccccccccccccccccccccccccc

c     all LMO on file
      open(unit=134,file='xtblmoinfo')
      open(unit=32,file='lmocent.coord')
      write(32,'(''$coord'')')
      write(134,*) nat
      do i=1,nat
         write(134,'(i2,3F20.10,E18.10)') at(i),xyz(1:3,i),q(i)
         write(32,'(3F24.10,5x,a2)') xyz(1:3,i),asym(at(i))
      enddo
      k=0
      do i=1,n+new
       if(int(rklmo(5,i)).gt.0)k=k+1
      enddo
c     dum=dble(m)/dble(m+npi)
c     if(dum.lt.0.01) dum=1.0d0
      write(134,'(i5,5f14.8)')k,diptot,elumo,ehomo,etot
      do i=1,n+new
       if(int(rklmo(5,i)).gt.0)then
       write(134,'(i2,3F20.10,f14.8)')int(rklmo(5,i)),rklmo(1:3,i)
       write(32,'(3F24.10,5x,a2)') rklmo(1:3,i),asym(2)
       endif
      enddo
      write(134,'(10(F10.6))') (qhl(i,1),i=1,nat)  ! HOMO atom pop
      write(134,'(10(F10.6))') (qhl(i,2),i=1,nat)  ! LUMO atom pop
      write(32,'(''$end'')')
      close(32)
      close(134)
c     call camm(nat,at,nbf,nao,xyz,s,p)

      if(.not.gbsa) close(134) ! if gbsa=.true. the calling routine add Gsolv to the end of the file
      write(*,*)'files:'
      write(*,*)'coordprot.0/xtbscreen.xyz/xtblmoinfo/lmocent.coord'
      write(*,*)'with protonation site input, xtbdock and'
      write(*,*)'LMO center info written'
      write(*,*)

      deallocate(xcen,cca,d,f,qmo,ecent,rklmo)

      end

c determine type of LMO
      subroutine lmotype(n,at,xyz,ex,ey,ez,ia1,ia2,xcen,modi,pithr,typ)
      implicit none
      integer n,ia1,ia2,at(n),typ
      logical modi
      real*8 xyz(3,n),ex,ey,ez,xcen,pithr
      real*8 r1,r2,r,r0,f,norm

      if(xcen.lt.1.3333333)then
         typ=2 ! LP
         f=-2.2
         if(modi)then
           norm=sqrt((xyz(1,ia1)-ex)**2+(xyz(2,ia1)-ey)**2
     .              +(xyz(3,ia1)-ez)**2)
c          the LP is on the atom e.g. in TM compounds so just shift it away
           if(norm.lt.0.2) then
              call shiftlp(n,at,ia1,xyz,ex,ey,ez)
           else
c          put it on the line along atom...LP center
              ex=ex+f*(xyz(1,ia1)-ex)
              ey=ey+f*(xyz(2,ia1)-ey)
              ez=ez+f*(xyz(3,ia1)-ez)
           endif
         endif
      else
         r1=sqrt(
     .   (xyz(1,ia1)-ex)**2+(xyz(2,ia1)-ey)**2+(xyz(3,ia1)-ez)**2)
         r2=sqrt(
     .   (xyz(1,ia2)-ex)**2+(xyz(2,ia2)-ey)**2+(xyz(3,ia2)-ez)**2)
         r=r1+r2
         r0=sqrt((xyz(1,ia1)-xyz(1,ia2))**2
     .          +(xyz(2,ia1)-xyz(2,ia2))**2
     .          +(xyz(3,ia1)-xyz(3,ia2))**2)
         if(r/r0.gt.1.04)then
            typ=3  ! pi
            if(xcen.gt.pithr) typ=4
         else
            typ=1  ! sigma
         endif
      endif

      end


cccccccccccccccccccccccccccccccccccccccc

      subroutine mocent(n,ndim,ihomo,x,s,qmo,xcen)
      implicit none
      integer n,ndim,ihomo
      real*8 xcen(ihomo),x(ndim,ndim),s(ndim,ndim)
      real*8 qmo(n,ihomo)
      include 'ehtcommon.fh'

      integer ia,ib,m,i,j,k
      real*8 dum,tmp

      qmo=0
!$OMP  PARALLEL PRIVATE (m,j,ia,k,ib,tmp,dum)
!$OMP& SHARED(qmo,xcen,X,S)
!$OMP& DEFAULT(SHARED)
!$OMP DO
      do m=1,ihomo
         do j=1,ndim
            ia=aoat2(j)
            do k=1,j-1
               ib=aoat2(k)
               tmp=X(j,m)*X(k,m)*s(k,j)
               qmo(ia,m)=qmo(ia,m)+tmp
               qmo(ib,m)=qmo(ib,m)+tmp
            enddo
            qmo(ia,m)=qmo(ia,m)+X(j,m)*X(j,m)*s(j,j)
         enddo
         dum=0
         do i=1,n
            dum=dum+qmo(i,m)**2
         enddo
         xcen(m)=1.0/(1.0d-8+dum)
      enddo
!$OMP END DO
!$OMP END PARALLEL

      end

      SUBROUTINE lmosort(ncent,ihomo,imo,imem,qmo)
      IMPLICIT REAL*8(A-H,O-Z)
      dimension qmo(ncent,ihomo)
      dimension imem(ncent)

      do 140   ii = 2,ncent
         i = ii - 1
         k = i
         pp= qmo(i,imo)
         do 120   j = ii, ncent
            if (qmo(j,imo) .lt. pp) go to 120
            k = j
            pp=qmo(j,imo)
  120    continue
         if (k .eq. i) go to 140
         qmo(k,imo) = qmo(i,imo)
         qmo(i,imo) = pp

         ihilf=imem(i)
         imem(i)=imem(k)
         imem(k)=ihilf
  140 continue

         end

      SUBROUTINE lmosort2(n,eps,d,ecent)
      IMPLICIT REAL*8(A-H,O-Z)
      dimension d(n,n), eps(n), ecent(n,3)

      do 140   ii = 2,n
         i = ii - 1
         k = i
         pp= eps(i)
         do 120   j = ii, n
            if (eps(j) .gt. pp) go to 120
            k = j
            pp=eps(j)
  120    continue
         if (k .eq. i) go to 140
         eps(k) = eps(i)
         eps(i) = pp

         do j=1,n
         hilf=d(j,i)
         d(j,i)=d(j,k)
         d(j,k)=hilf
         enddo

         do j=1,3
         hilf=ecent(i,j)
         ecent(i,j)=ecent(k,j)
         ecent(k,j)=hilf
         enddo

  140 continue

         end


      subroutine lmoneigh(n,rk,ecent,aneigh,neigh)
      implicit none
      integer n,neigh(4,n),aneigh(2,*)
      real*8 ecent(n,3)
      real*4 rk(5,2*n)

      real*8 rr(n)
      integer i,j,ind(n),i1,i2,j1,j2

      do i=1,n
         i1=aneigh(1,i)
         i2=aneigh(2,i)
         do j=1,n
            j1=aneigh(1,j)
            j2=aneigh(2,j)
            rr(j)= (ecent(i,1)-ecent(j,1))**2
     .            +(ecent(i,2)-ecent(j,2))**2
     .            +(ecent(i,3)-ecent(j,3))**2
            if(int(rk(5,j)).eq.2) rr(j)=1.d+42  ! LP
            if(i1.eq.j1.and.i2.eq.j2) rr(j)=-1.0 ! same bond?
            if(i1.eq.j2.and.i2.eq.j1) rr(j)=-1.0
            if(i.eq.j) rr(j)=2.d+42
            ind(j)=j
         enddo
         call Qsort(rr,1,n,ind)
         neigh(1,i)=ind(1)
         neigh(2,i)=ind(2)
         neigh(3,i)=ind(3)
         neigh(4,i)=ind(4)
      enddo

      end

      subroutine atomneigh(n,nat,xyz,ecent,neigh)
      implicit none
      integer n,nat,neigh(2,n)
      real*8 ecent(n,3)
      real*8 xyz(3,nat)

      real*8 rr(nat)
      integer i,j,ind(nat)

      do i=1,n
         do j=1,nat
            rr(j)= (ecent(i,1)-xyz(1,j))**2
     .            +(ecent(i,2)-xyz(2,j))**2
     .            +(ecent(i,3)-xyz(3,j))**2
            ind(j)=j
         enddo
         call Qsort(rr,1,nat,ind)
         neigh(1,i)=ind(1)
         neigh(2,i)=ind(2)
      enddo

      end

      logical function bndcheck(nat,list,i1,i2)
      integer nat,list(nat),i1,i2
      bndcheck=.false.
      if(list(i1).eq.1.and.list(i2).eq.1) bndcheck=.true.
      end

      subroutine irand3(n1,n2,n3)
      integer n1,n2,n3,irand
      real x

      call random_number(x)
      irand=int(3.1*x)
      if(irand.lt.1) irand=1
      if(irand.gt.3) irand=3
      n1=irand
 10   call random_number(x)
      irand=int(3.1*x)
      if(irand.lt.1) irand=1
      if(irand.gt.3) irand=3
      if(irand.ne.n1)then
         n2=irand
      else
         goto 10
      endif
 20   call random_number(x)
      irand=int(3.1*x)
      if(irand.lt.1) irand=1
      if(irand.gt.3) irand=3
      if(irand.ne.n1.and.irand.ne.n2)then
         n3=irand
      else
         goto 20
      endif

      end

      subroutine threeoutfour(i1,i2,j1,j2,n1,n2,n3)
      integer i1,i2,j1,j2,n1,n2,n3

      n1=0
      if(i1.eq.j1)then
         n1=i2
         n2=i1
         n3=j2
         return
      endif
      if(i1.eq.j2)then
         n1=i2
         n2=i1
         n3=j1
         return
      endif
      if(i2.eq.j1)then
         n1=i1
         n2=i2
         n3=j2
         return
      endif
      if(i2.eq.j2)then
         n1=i1
         n2=i2
         n3=j1
         return
      endif

      end

      subroutine calcrotation(x,ori,vec,phi)
      implicit none

      integer i,j

      real*8 :: x(3),ori(3),vec(3),d(3)
      real*8 :: phi
      real*8 :: xtmp(3)
      real*8 :: absd

       d(1:3) = vec(1:3)

       xtmp(1:3) = x(1:3) - ori(1:3)

       absd = sqrt(d(1)**2 + d(2)**2 + d(3)**2)

       d(1:3) = d(1:3) / absd

       x(1) = ( (d(2)**2+d(3)**2)*cos(phi) + d(1)**2 ) * xtmp(1) +
     .      ( d(1)*d(2)*(1-cos(phi))-d(3)*sin(phi) ) * xtmp(2) +
     .      ( d(1)*d(3)*(1-cos(phi))+d(2)*sin(phi) ) * xtmp(3)
       x(2) = ( d(1)*d(2)*(1-cos(phi))+d(3)*sin(phi) ) * xtmp(1) +
     .      ( (d(1)**2+d(3)**2)*cos(phi) + d(2)**2 ) * xtmp(2) +
     .    ( d(2)*d(3)*(1-cos(phi))-d(1)*sin(phi) ) * xtmp(3)
       x(3) = ( d(1)*d(3)*(1-cos(phi))-d(2)*sin(phi) ) * xtmp(1) +
     .      ( d(2)*d(3)*(1-cos(phi))+d(1)*sin(phi) ) * xtmp(2) +
     .      ( (d(1)**2+d(2)**2)*cos(phi) + d(3)**2 ) * xtmp(3)
       x(1:3) = x(1:3) + ori(1:3)

      end

      subroutine piorient(a,b,flip)
      implicit none
      integer i,j
      real*8 a(3),b(3),d(3),d2(3)
      logical flip
      flip=.false.
      d=0.0d0
      j=0

      do i=1,3
         d(i)=a(i)-b(i)
         d2(i)=d(i)*d(i)
      enddo
      j=maxloc(d2,1)
      if(d(j).lt.0.0d0) flip=.true.
      return
      end subroutine piorient


