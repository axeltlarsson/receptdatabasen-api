import { rest_service, resetdb } from '../common'
import { should } from 'should'

describe('auth', function () {
  before(function (done) { resetdb(); done() })
  after(function (done) { resetdb(); done() })

  it('login', function (done) {
    rest_service()
      .post('/rest/login')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        email: 'alice@email.com',
        password: 'pass'
      })
      .expect('Content-Type', /json/)
      .expect('Set-Cookie', /session/)
      .expect(r => {
        r.body.me.email.should.equal('alice@email.com')
        r.body.should.not.have.ownProperty('token')
      }).expect(200, done)
  })

  it('me', function (done) {
    rest_service()
      .post('/rest/rpc/me')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .withRole('webuser')
      .send({})
      .expect('Content-Type', /json/)
      .expect(200, done)
  })

  it('refresh_token', function (done) {
    rest_service()
      .post('/rest/rpc/refresh_token')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .withRole('webuser')
      .send({})
      .expect('Content-Type', /json/)
      .expect(404, done)
  })

  it('signup', function (done) {
    rest_service()
      .post('/rest/rpc/signup')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        name: 'John Doe',
        email: 'john@email.com',
        password: 'pass'
      })
      .expect('Content-Type', /json/)
      .expect(404, done)
  })
})


describe('unauthenticated', function () {
  before(function (done) { resetdb(); done() })
  after(function (done) { resetdb(); done() })

  it('/login', function (done) {
    rest_service(false)
      .post('/rest/login')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        email: 'alice@email.com',
        password: 'pass'
      })
      .expect('Content-Type', /json/)
      .expect('Set-Cookie', /session/)
      .expect(r => {
        r.body.me.email.should.equal('alice@email.com')
        r.body.should.not.have.ownProperty('token')
      }).expect(200, done)
  })

  it('/recipes', function (done) {
    rest_service(false)
      .get('/rest/recipes?select=id,title')
      .expect('Content-Type', /json/)
      .expect((r) => {
        r.body.error.should.equal("You need a valid session to access this endpoint")
      })
      .expect(403, done)
  })
})
